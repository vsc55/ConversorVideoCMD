<#
    Config.psm1 - Valores por defecto de config.json, carga y fusion.
    Get-CvConfigDefaults es la FUENTE UNICA de los defaults; Get-CvConfig los fusiona
    (fusion profunda) con el config.json del usuario. Sin dependencias de otros modulos.
#>

function Merge-CvConfig {
    <#
        Fusiona (en sitio) $Override (objeto de JSON) sobre $Default (ordered hashtable),
        recorriendo secciones anidadas. Los escalares y arrays se reemplazan; las
        subsecciones (objetos) se fusionan recursivamente para no perder claves ausentes.
    #>
    param($Default, $Override)
    if ($null -eq $Override) { return }
    # Sobreescribir/fusionar las claves existentes.
    foreach ($key in @($Default.Keys)) {
        if ($Override.PSObject.Properties[$key] -and $null -ne $Override.$key) {
            $dv = $Default[$key]
            $ov = $Override.$key
            if ($dv -is [System.Collections.IDictionary] -and $ov -is [System.Management.Automation.PSCustomObject]) {
                Merge-CvConfig -Default $dv -Override $ov
            } else {
                $Default[$key] = $ov
            }
        }
    }
    # Anadir claves nuevas que solo estan en el override (ej: versiones de ffmpeg extra).
    foreach ($prop in $Override.PSObject.Properties) {
        if (-not $Default.Contains($prop.Name) -and $null -ne $prop.Value) {
            $Default[$prop.Name] = $prop.Value
        }
    }
}

function Get-CvVolumeMethods {
    <# FUENTE UNICA de los metodos de normalizacion de volumen validos (el 1o es el fallback). #>
    @('peak','loudnorm','aacgain')
}

function Resolve-CvOneOf {
    <#
        Valida una opcion enum: devuelve $Value en minusculas si esta en $Valid (comparacion sin
        distinguir mayusculas); si no, $Default. Se usa para las opciones de config con conjunto
        cerrado de valores (p. ej. multipass, tonemapHdr, downmixMode), cayendo al default si el
        valor de config.json no es valido.
    #>
    param([string]$Value, [string[]]$Valid, [string]$Default)
    $v = "$Value".ToLower()
    foreach ($x in $Valid) { if ($v -eq "$x".ToLower()) { return $v } }
    return $Default
}

function Get-CvDefaultDownmixCoeffs {
    <#
        FUENTE UNICA de los coeficientes por defecto del downmix 'dialogue' (voz reforzada). La usan
        el default de config (encode.downmixCoeffs) y los fallbacks de Context/Profile cuando la
        config/perfil omite alguna subclave, para no repetir los numeros en varios sitios.
        center = canal central (dialogos), front = frontales, surround = surrounds (el LFE se descarta).
    #>
    [ordered]@{ Center = 0.5; Front = 0.35; Surround = 0.15 }
}

function Get-CvConfigDefaults {
    <# Valores por defecto de config.json (fuente unica: los usa Get-CvConfig y el reset). #>
    $langs = @('spa','es','esp','es-es','es_es','castellano','spanish')
    $dmc   = Get-CvDefaultDownmixCoeffs   # coeficientes por defecto del downmix dialogue (fuente unica)
    [ordered]@{
        downloads = [ordered]@{
            ffmpeg = [ordered]@{
                selected     = '8.1.2'
                type         = 'zip'
                url          = 'https://github.com/GyanD/codexffmpeg/releases/download/{version}/ffmpeg-{version}-full_build.zip'
                binPath      = 'ffmpeg-{version}-full_build/bin'
                files        = @('ffmpeg.exe','ffprobe.exe','ffplay.exe')
                platform     = 'x86_64'
                versionExe   = 'ffmpeg.exe'
                versionArgs  = @('-version')
                versionRegex = 'ffmpeg version (\d+\.\d+(?:\.\d+)?)'
                versions = [ordered]@{
                    '8.1.2' = 'b8cdefab5f50590a076c27c2b56b0294a0e6154faded28ba1ba05ebc4f801f57'
                    '7.1.1' = 'd760e1b3574402ed18b4865851f87d87e73965a982e6453212df8621fed1c508'
                    '5.1.2' = '1f4056c147694228fddaeb925083338e35d952e4b65e3bd3c5a0a2c13c7800d6'
                }
            }
            aacgain = [ordered]@{
                selected     = '2.0.0'
                type         = 'file'
                url          = 'https://github.com/dgilman/aacgain/releases/download/{version}/aacgain-{version}-windows-amd64.exe'
                files        = @('aacgain.exe')
                platform     = 'x86_64'
                versionExe   = 'aacgain.exe'
                versionArgs  = @('/v')
                versionRegex = '[Vv]ersion (\d+\.\d+(?:\.\d+)?)'
                versions     = [ordered]@{
                    '2.0.0' = 'd960cedbd274881badd3dd914475ca23bb31c27b3a5cab881ff0d1515a37371a'
                }
            }
            # 7zr: extractor 7z minimo (un solo .exe). Es el 'bootstrap' que necesita mkvtoolnix
            # (que se distribuye como .7z/LZMA y no lo abre Expand-Archive ni el tar de Windows).
            sevenzip = [ordered]@{
                selected     = '26.02'
                type         = 'file'
                url          = 'https://github.com/ip7z/7zip/releases/download/{version}/7zr.exe'
                files        = @('7zr.exe')
                platform     = 'x86_64'
                versionExe   = '7zr.exe'
                versionArgs  = @()
                versionRegex = '7-Zip.*?(\d+\.\d+)'
                versions     = [ordered]@{
                    '26.02' = '56b8cc9f4971cef253644fafe54063ed7fdca551d4dee0f8c6baa81b855acd72'
                }
            }
            # mkvtoolnix: solo se usa 'mkvpropedit.exe' para limpiar las etiquetas DURATION del
            # MKV final. Se distribuye como .7z (se extrae con 7zr). El exe es autosuficiente.
            mkvtoolnix = [ordered]@{
                selected     = '100.0'
                type         = '7z'
                url          = 'https://mkvtoolnix.download/windows/releases/{version}/mkvtoolnix-64-bit-{version}.7z'
                binPath      = 'mkvtoolnix'
                files        = @('mkvpropedit.exe')
                dependsOn    = @('sevenzip')   # 7zr para extraer el .7z (LZMA)
                platform     = 'x86_64'
                versionExe   = 'mkvpropedit.exe'
                versionArgs  = @('--version')
                versionRegex = 'mkvpropedit v(\d+\.\d+)'
                versions     = [ordered]@{
                    '100.0' = '061de38bd10e7e28697b897e0b890b78d6f2ec8d668a9c198600ed45c19672ab'
                }
            }
        }
        languages = [ordered]@{ audio = $langs; subtitle = $langs }
        # encode: outputExtension = contenedor de salida; extensions = extensiones de ENTRADA que
        # se procesan de Original\ (sin punto); audioChannels = canales del audio recodificado, tratado
        # como MAXIMO (no hace upmix: si el origen tiene menos canales, se conservan los del origen; 2
        # = estereo; 6 = 5.1; 8 = 7.1); fps/audioHz para ffmpeg. threads = -threads de ffmpeg:
        # 0 = auto (usa TODOS los nucleos de CPU); N para limitar (util con encoders CPU + varios
        # workers, que si no se pisan). Con NVENC casi no influye (trabaja la GPU).
        # forceFps: si $true (por defecto) se fuerza la salida a 'fps' (-r), reajustando (dup/drop)
        #   los videos con otro fps de origen; si $false, se CONSERVA el fps de cada archivo (sin -r).
        # multipass: 2-pass de NVENC (solo hevc_nvenc/h264_nvenc). 'off' (por defecto) | 'qres'
        #   (1a pasada a 1/4 de resolucion) | 'fullres' (a resolucion completa). Mas calidad a costa
        #   de mas tiempo de GPU. No afecta a los encoders de CPU (libx264/libx265).
        # tonemapHdr: convierte el HDR (BT.2020/PQ o HLG) a SDR BT.709 al recodificar, para que no se
        #   vea "lavado" al reproducir en SDR. 'auto' (por defecto) = solo actua si el origen es HDR;
        #   'off' = nunca (deja el video como esta). Usa el filtro libplacebo en la GPU (Vulkan).
        # downmixMode: SOLO al bajar 5.1 -> estereo (audioChannels=2). 'default' (por defecto) = downmix
        #   estandar de ffmpeg. 'dialogue' (BETA) = downmix con VOZ REFORZADA (filtro pan que sube el
        #   canal central —dialogos— y baja los surrounds), para que los dialogos no queden bajos frente
        #   al ambiente/efectos. No aplica si la salida no es estereo o el origen no es 5.1. BETA: los
        #   coeficientes del pan son provisionales, pendientes de validar/afinar con mas material.
        # downmixCoeffs: pesos del downmix 'dialogue' (voz reforzada). center = canal central (dialogos),
        #   front = frontales L/R, surround = surrounds; el LFE siempre se descarta. Cada salida =
        #   center*central + front*frontal + surround*surround. Para que sea clip-safe (el pico no supere
        #   al del origen) deben sumar <= 1.0; por encima puede recortar. El filtro pan se construye de
        #   estos valores, asi que se pueden afinar sin tocar codigo. Solo se usan con downmixMode=dialogue.
        # multiAudio (BETA): si $true, cuando hay 2+ pistas del idioma preferido se ofrece conservar
        #   VARIAS (no solo la mejor) y elegir cual queda como predeterminada. Doble llave mientras sea
        #   beta: SOLO se activa si ademas test.betaMultiAudio=$true; si no, se comporta como monopista
        #   (elige una, como siempre). Con 0-1 pistas del idioma preferido no cambia nada.
        # audioKeepTitle: si $true, la(s) pista(s) de audio de salida CONSERVAN el titulo del origen
        #   (util para distinguir varias del mismo idioma: principal/comentarios/...). Por defecto
        #   $false = titulo en blanco (como el resto de pistas recodificadas).
        encode    = [ordered]@{ outputExtension = 'mkv'; extensions = @('avi','flv','mp4','mov','mkv'); threads = 0; fps = '23.976'; forceFps = $true; multipass = 'off'; tonemapHdr = 'auto'; downmixMode = 'default'; downmixCoeffs = [ordered]@{ center = $dmc.Center; front = $dmc.Front; surround = $dmc.Surround }; audioHz = 44100; audioChannels = 2; multiAudio = $true; audioKeepTitle = $false }
        # customProfile: valores por DEFECTO del constructor de perfil CUSTOM interactivo (opcion 0
        #   del menu USAR PERFIL). En cada menu, ENTER acepta el valor por defecto (o eliges otro).
        #   videoEncoder: libx264|h264_nvenc|libx265|hevc_nvenc|copy. videoProfile: main|main10|...
        #   (segun codec). videoLevel: 4.0|4.1|5.0|... (segun codec). Se ignoran si no aplican al codec.
        #   qmin/qmax: control de tasa por defecto en NVENC. crf: control de tasa por defecto en CPU.
        #     Rango 0-51; -1 (o negativo) = AUTO (sin -qmin/-qmax ni -crf; decide el encoder).
        #   audioBitrate: bitrate de audio por defecto ('copy' = copiar la pista sin recodificar).
        #   audioCodec: codec de salida por defecto al recodificar: aac|ac3|eac3|libmp3lame|flac|libopus.
        customProfile = [ordered]@{ videoEncoder = 'hevc_nvenc'; videoProfile = 'main10'; videoLevel = '5.0'; qmin = 1; qmax = 23; crf = 21; multipass = 'off'; audioCodec = 'aac'; audioBitrate = '192k' }
        # border: deteccion de bordes negros con cropdetect.
        #  - start: segundo del primer punto de escaneo. duration: segundos que escanea CADA punto.
        #  - samples: en cuantos puntos repartidos del video se escanea (1 = solo al inicio, clasico).
        #  - autoAcceptPct: si el recorte mas votado alcanza este % de los puntos que detectaron
        #    borde, se acepta AUTOMATICAMENTE (se descartan los atipicos); por debajo, se pregunta.
        #  - autoAcceptMinMargin: ADEMAS del %, el mas votado debe superar al 2o por al menos estos
        #    votos. Evita auto-aceptar con evidencia debil cuando hay pocas muestras (2/3 = 67% pero
        #    solo 1 de margen -> pregunta; 6/9 = 67% con 3+ de margen -> auto). 0 = sin margen.
        #  - autoSamples/autoDuration: puntos y segundos del PRE-ESCANEO del modo 'auto' del perfil
        #    (DetectBorder='auto'), mas ligero que el escaneo normal (pocos puntos y cortos). OJO: el
        #    escaneo aplica un minimo de 5 s por punto (cropdetect necesita estabilizarse), asi que
        #    autoDuration < 5 se trata como 5. minCropPct: reduccion minima (%) para considerar que
        #    hay barras de verdad (por debajo = ruido de borde -> no recorta). El modo 'auto' reusa
        #    autoAcceptPct/autoAcceptMinMargin para el voto de mayoria.
        border    = [ordered]@{ start = 120; duration = 120; samples = 9; autoAcceptPct = 60; autoAcceptMinMargin = 2; autoSamples = 3; autoDuration = 5; minCropPct = 2 }
        # preview: previsualizacion con ffplay en PREPARAR (pista audio/video, comparacion de bordes).
        #   start = segundo donde empieza (0 = desde el principio). seconds = duracion de la muestra
        #   (0 = SIN limite: reproduce hasta el final o hasta que el usuario cierre con q/ESC). El
        #   comando 'P N <seg>' de los menus fuerza el inicio en ese segundo puntual.
        preview   = [ordered]@{ start = 0; seconds = 0 }
        # volume: metodo de normalizacion. peakTarget = pico objetivo en dBFS del metodo 'peak'
        # (0 = maximo sin recorte; -1 deja margen/headroom contra el clipping inter-sample del AAC).
        volume    = [ordered]@{ method = 'peak'; peakTarget = 0; loudnorm = [ordered]@{ I = -16; TP = -1.5; LRA = 11 } }
        # Postproceso del MKV final:
        #  - stripTags: limpiar con mkvpropedit las etiquetas DURATION por pista que anade el
        #    muxer de ffmpeg (mkvpropedit vacio = usar la version descargada en tools\).
        #  - attachments: conservar adjuntos del original, permitiendo/excluyendo por categoria
        #    (keep = interruptor maestro; fonts = fuentes p. ej. para subtitulos ASS; covers =
        #    caratulas/imagenes; other = el resto).
        postprocess = [ordered]@{
            stripTags   = $true
            mkvpropedit = ''
            attachments = [ordered]@{ keep = $false; fonts = $true; covers = $false; other = $false }
        }
        # promptTimeout: auto-aceptar el valor por defecto en las preguntas simples de PREPARAR si no
        #   se teclea nada durante N segundos (contador de inactividad; cualquier tecla lo reinicia).
        #   'default' = timeout GENERICO en segundos (0 = desactivado). El resto son overrides por tipo
        #   de pregunta: -1 = usar el generico; >=0 = valor propio (0 = desactivado solo para esa).
        #   'sync' (silencio de sincronia), 'border' (deteccion de bordes), 'animation' (video de
        #   animacion), y los menus de seleccion 'video'/'audio'/'subtitle' (al expirar toman la opcion
        #   por defecto: la pista preseleccionada, o 'ninguno' en subtitulos). Los menus vienen a -1
        #   (heredan del generico, que por defecto es 0 = off) para no auto-elegir pista sin querer;
        #   sube 'default' o cada menu para dejar PREPARAR desatendido. Para una pregunta/menu nuevo
        #   basta anadir su clave aqui (sin tocar codigo salvo pasar su nombre a Get-CvPromptTimeout).
        # progress: en los pasos largos (recodificar video/audio) muestra una linea VIVA con % y ETA
        #   ( - Procesando Video...  42%  ETA 03:12  1.8x) leyendo el '-progress' de ffmpeg, en vez de
        #   lanzarlo en una ventana aparte y esperar al ✓. $true (por defecto) = progreso inline; $false
        #   = comportamiento clasico (ventana aparte / ✓ al final). En modo debug no aplica (se ve el
        #   log de ffmpeg). Convive con separateWindow: si progress esta activo, esos pasos van inline.
        behavior  = [ordered]@{ cleanTemps = $true; separateWindow = $true; lockCloseButton = $true; debug = $false; log = $true; workers = 2; retries = 2; asciiMarks = $false; progress = $true
                                promptTimeout = [ordered]@{ default = 0; sync = 5; border = 10; animation = 10; video = -1; audio = -1; subtitle = -1 } }
        # Modo pruebas: si 'enabled', cada archivo se codifica solo hasta 'minutes' minutos (el resto
        #   se descarta). Sirve para validar perfiles/ajustes rapido. Tambien se activa con 'test_on'.
        #   syncAdelay (BETA): si $true, el silencio de sincronia se aplica con el filtro 'adelay' en
        #   UNA sola pasada (combinado con la normalizacion de volumen), sin el WAV intermedio. Por
        #   defecto $false = metodo clasico (genera WAV silencio+pista y luego lo codifica).
        #   betaDownmix (BETA): activador del downmix 'dialogue' (voz reforzada). Mientras esa mezcla
        #   sea beta hay doble llave: encode.downmixMode='dialogue' fija el modo, pero SOLO refuerza la
        #   voz si betaDownmix=$true. Con $false (por defecto), aunque downmixMode sea 'dialogue' se usa
        #   el downmix estandar de ffmpeg. Al promocionar la mezcla se retira este flag.
        #   betaMultiAudio (BETA): activador de la multipista de audio (conservar varias pistas del
        #   idioma preferido y elegir la predeterminada). Doble llave: encode.multiAudio=$true habilita
        #   la funcion, pero SOLO actua si betaMultiAudio=$true. Con $false (por defecto) el audio es
        #   monopista, identico al comportamiento clasico. Al promocionar se retira este flag.
        test      = [ordered]@{ enabled = $false; minutes = 5; syncAdelay = $false; betaDownmix = $false; betaMultiAudio = $false }
        console   = [ordered]@{ background = 'DarkBlue'; foreground = 'Yellow'; font = 'Cascadia Code'; fontSize = 18; windowWidth = 150; windowHeight = 40; sepWidth = 64; progressBarWidth = 20 }
        # Carpetas de trabajo: vacio = junto al programa; admite ruta absoluta o relativa.
        paths     = [ordered]@{ original = ''; proceso = ''; convertido = ''; logs = '' }
        # Perfiles de codificacion PROPIOS: se ANADEN a los 7 de serie en el menu USAR PERFIL
        # (no los sustituyen). Cada objeto admite: label, videoEncoder, videoProfile, videoLevel,
        # qmin, qmax, crf, detectBorder, changeSize, audioEncoder, audioCodec, audioBitrate, audioHz.
        # Ejemplo: { "label":"Anime 1080p", "videoEncoder":"libx265", "crf":18, "changeSize":"1920:-2" }
        profiles  = @()
    }
}

function Get-CvConfigHelp {
    <#
        Catalogo de AYUDA de las opciones de config.json: { 'ruta/clave' -> descripcion corta }.
        La ruta usa '/' igual que el navegador del editor (setup.ps1 Edit-Node): claves de raiz
        'seccion'; anidadas 'seccion/clave'; profundas 'seccion/sub/clave'. Lo consume setup.ps1
        para mostrar, junto a cada opcion, que hace. Fuente unica de los textos (los comentarios
        de Get-CvConfigDefaults son la version larga).
    #>
    @{
        'downloads' = 'Catalogo de herramientas descargables (ffmpeg, aacgain, 7zr, mkvpropedit); se gestiona desde el menu Herramientas'

        'languages'          = "Idiomas preferidos (etiquetas que cuentan como 'espanol')"
        'languages/audio'    = 'Etiquetas de idioma preferidas al elegir la pista de audio'
        'languages/subtitle' = 'Etiquetas de idioma preferidas al elegir/conservar subtitulos'

        'encode'                = 'Ajustes de codificacion (contenedor, fps, audio, HDR...)'
        'encode/outputExtension'= 'Contenedor de salida (mkv recomendado; mp4/mov admiten +faststart)'
        'encode/extensions'     = 'Extensiones de entrada que se procesan de Original\ (sin punto)'
        'encode/threads'        = '-threads de ffmpeg: 0 = todos los nucleos; N para limitar'
        'encode/fps'            = "Fps de salida cuando forceFps=true (ej 23.976)"
        'encode/forceFps'       = "true = fuerza la salida a 'fps' (-r); false = conserva el fps de origen"
        'encode/multipass'      = '2-pass NVENC: off | qres (1/4 res) | fullres. Mas calidad, mas GPU'
        'encode/tonemapHdr'     = 'HDR->SDR BT.709 al recodificar: auto (solo si origen HDR) | off'
        'encode/downmixMode'    = 'Al bajar 5.1->estereo: default | dialogue (refuerza la voz)'
        'encode/downmixCoeffs'        = 'Pesos del downmix dialogue (voz reforzada); solo con downmixMode=dialogue'
        'encode/downmixCoeffs/center' = 'Peso del canal central (dialogos) en el downmix dialogue'
        'encode/downmixCoeffs/front'  = 'Peso de los frontales L/R en el downmix dialogue'
        'encode/downmixCoeffs/surround' = 'Peso de los surrounds en el downmix dialogue (el LFE se descarta)'
        'encode/audioHz'        = 'Frecuencia del audio recodificado (Hz); opus fuerza 48000'
        'encode/audioChannels'  = 'Canales de salida (MAXIMO, no hace upmix): 2 = estereo, 6 = 5.1, 8 = 7.1'
        'encode/multiAudio'     = 'BETA: con 2+ pistas del idioma preferido, conservar varias y elegir la predeterminada (requiere test.betaMultiAudio)'
        'encode/audioKeepTitle' = 'Conservar el titulo del audio de origen en la salida (false = titulo en blanco)'

        'customProfile'             = 'Valores por defecto del constructor de perfil CUSTOM (opcion 0 de USAR PERFIL)'
        'customProfile/videoEncoder'= 'Codec de video: libx264|h264_nvenc|libx265|hevc_nvenc|copy'
        'customProfile/videoProfile'= 'Perfil del codec (main|main10|...); se ignora si no aplica'
        'customProfile/videoLevel'  = 'Nivel del codec (4.0|4.1|5.0|...); se ignora si no aplica'
        'customProfile/qmin'        = 'Q minimo del control de tasa en NVENC (0-51)'
        'customProfile/qmax'        = 'Q maximo del control de tasa en NVENC (0-51)'
        'customProfile/crf'         = 'CRF por defecto en encoders de CPU (0-51); -1 = auto'
        'customProfile/multipass'   = '2-pass NVENC del perfil custom: off | qres | fullres'
        'customProfile/audioCodec'  = 'Codec de audio: aac|ac3|eac3|libmp3lame|flac|libopus'
        'customProfile/audioBitrate'= "Bitrate de audio ('copy' = copiar sin recodificar)"

        'border'                    = 'Deteccion de bordes negros con cropdetect'
        'border/start'              = 'Segundo del primer punto de escaneo'
        'border/duration'           = 'Segundos que escanea CADA punto'
        'border/samples'            = 'En cuantos puntos repartidos se escanea (1 = solo al inicio)'
        'border/autoAcceptPct'      = '% de puntos que deben coincidir para auto-aceptar el recorte'
        'border/autoAcceptMinMargin'= 'Votos de ventaja sobre el 2o para auto-aceptar (0 = sin margen)'
        'border/autoSamples'        = "Puntos del pre-escaneo del modo 'auto' del perfil"
        'border/autoDuration'       = "Segundos por punto del pre-escaneo 'auto' (minimo real 5 s)"
        'border/minCropPct'         = 'Reduccion minima (%) para considerar barras (menos = no recorta)'


        'preview'         = 'Previsualizacion con ffplay en PREPARAR'
        'preview/start'   = 'Segundo en que empieza la muestra (0 = desde el principio)'
        'preview/seconds' = 'Duracion de la muestra en seg (0 = sin limite, todo el video)'

        'volume'             = 'Normalizacion de volumen del audio'
        'volume/method'      = ('Metodo: {0}' -f ((Get-CvVolumeMethods) -join ' | '))
        'volume/peakTarget'  = "Pico objetivo dBFS de 'peak' (0 = maximo; -1 deja headroom)"
        'volume/loudnorm'    = 'Parametros EBU R128 del metodo loudnorm'
        'volume/loudnorm/I'  = 'Loudness integrada objetivo (LUFS), ej -16'
        'volume/loudnorm/TP' = 'True Peak maximo (dBTP), ej -1.5'
        'volume/loudnorm/LRA'= 'Rango de loudness objetivo (LU), ej 11'

        'postprocess'                    = 'Postproceso del MKV final'
        'postprocess/stripTags'          = 'Limpiar con mkvpropedit las etiquetas DURATION que anade ffmpeg'
        'postprocess/mkvpropedit'        = 'Ruta a mkvpropedit (vacio = usar la de tools\)'
        'postprocess/attachments'        = 'Conservar adjuntos del original (fuentes, caratulas...)'
        'postprocess/attachments/keep'   = 'Interruptor maestro: conservar adjuntos del original'
        'postprocess/attachments/fonts'  = 'Conservar fuentes (p. ej. para subtitulos ASS)'
        'postprocess/attachments/covers' = 'Conservar caratulas/imagenes'
        'postprocess/attachments/other'  = 'Conservar el resto de adjuntos'

        'behavior'                          = 'Comportamiento general del conversor'
        'behavior/cleanTemps'               = 'Borrar los temporales de Proceso\ al terminar cada archivo'
        'behavior/separateWindow'           = 'Lanzar cada codificacion en su propia ventana'
        'behavior/lockCloseButton'          = 'Desactivar el boton X mientras hay conversiones en marcha'
        'behavior/debug'                    = 'Mensajes de depuracion detallados'
        'behavior/log'                      = 'Guardar log (transcript) de la sesion en logs\'
        'behavior/workers'                  = 'Codificaciones en paralelo al terminar PREPARAR (esta + N-1)'
        'behavior/retries'                  = 'Reintentos por archivo cuando la codificacion falla'
        'behavior/asciiMarks'               = 'Marcas en ASCII puro ([OK]/[ERROR]) en vez de simbolos'
        'behavior/progress'                 = 'Linea viva con % y ETA al recodificar (inline); false = ventana aparte + solo ✓'
        'behavior/promptTimeout'            = 'Auto-aceptar el valor por defecto en preguntas de PREPARAR tras N s de inactividad'
        'behavior/promptTimeout/default'    = 'Timeout generico en segundos (0 = desactivado)'
        'behavior/promptTimeout/sync'       = 'Timeout de la pregunta de sincronia (-1 = usar el generico)'
        'behavior/promptTimeout/border'     = 'Timeout de la pregunta de bordes (-1 = usar el generico)'
        'behavior/promptTimeout/animation'  = 'Timeout de la pregunta de animacion (-1 = usar el generico)'
        'behavior/promptTimeout/video'      = 'Timeout del menu de seleccion de pista de video (-1 = generico; toma la preseleccionada)'
        'behavior/promptTimeout/audio'      = 'Timeout del menu de seleccion de pista de audio (-1 = generico; toma la preseleccionada)'
        'behavior/promptTimeout/subtitle'   = 'Timeout del menu de subtitulos fallback (-1 = generico; al expirar no conserva ninguno)'

        'test'            = 'Modo pruebas (codificacion parcial para validar ajustes)'
        'test/enabled'    = "Activar modo pruebas: cada archivo solo se codifica hasta 'minutes' min"
        'test/minutes'    = 'Minutos que se codifican por archivo en modo pruebas (>=1)'
        'test/syncAdelay' = 'BETA: silencio de sincronia con adelay en una sola pasada (sin WAV)'
        'test/betaDownmix'= 'BETA: activa el downmix dialogue (voz reforzada); sin el, dialogue = downmix estandar'
        'test/betaMultiAudio' = 'BETA: activa la multipista de audio (encode.multiAudio); sin el, el audio es monopista'

        'console'             = 'Apariencia de la ventana de consola'
        'console/background'  = 'Color de fondo de la consola'
        'console/foreground'  = 'Color de texto de la consola'
        'console/font'        = 'Fuente de la consola (ej Cascadia Code / Consolas)'
        'console/fontSize'    = 'Tamano de la fuente'
        'console/windowWidth' = 'Ancho de la ventana en columnas (0 = no cambiar)'
        'console/windowHeight'= 'Alto de la ventana en lineas (0 = no cambiar)'
        'console/sepWidth'    = 'Ancho (caracteres) de los separadores de seccion === / --- de la UI'
        'console/progressBarWidth' = 'Ancho (caracteres) de la barra visual de progreso del worker; 0 = sin barra'

        'paths'            = 'Carpetas de trabajo (vacio = junto al programa)'
        'paths/original'   = 'Carpeta de entrada (videos a convertir)'
        'paths/proceso'    = 'Carpeta de temporales durante la conversion'
        'paths/convertido' = 'Carpeta de salida (videos ya convertidos)'
        'paths/logs'       = 'Carpeta de logs de sesion'

        'profiles' = 'Perfiles propios (se anaden a los de serie); se editan a mano en el fichero de config'
    }
}

function Get-CvHelpFor {
    <# Ayuda de una opcion por su ruta ('seccion/clave'); '' si no hay entrada. #>
    param([string]$Path)
    $h = Get-CvConfigHelp
    if ($h.ContainsKey($Path)) { return $h[$Path] }
    return ''
}

function Get-CvConfigDefaultValue {
    <#
        Valor POR DEFECTO (de Get-CvConfigDefaults) de una opcion, por su ruta con '/' ('seccion/clave',
        'seccion/sub/clave'). Devuelve $null si la ruta no existe. Lo usa el editor de setup para marcar
        el default real (no el valor actual). Los defaults son todo [ordered]@{}, asi que se navega por
        clave nivel a nivel.
    #>
    param([string]$Path)
    $node = Get-CvConfigDefaults
    foreach ($seg in ($Path -split '/')) {
        if ($node -isnot [System.Collections.IDictionary] -or -not $node.Contains($seg)) { return $null }
        $node = $node[$seg]
    }
    return $node
}

function ConvertTo-CvPromptTimeouts {
    <#
        Normaliza behavior.promptTimeout a un [ordered]@{ tipo = segundos(int) } con 'default'
        garantizado. Acepta un objeto (ordered/PSCustomObject) o el formato antiguo escalar (que se
        interpreta como el generico 'default'). Los tipos ausentes o -1 heredan de 'default' en
        tiempo de resolucion (Get-CvPromptTimeout), aqui solo se convierte a enteros.
    #>
    param($Node)
    $map = [ordered]@{ default = 0 }
    if ($null -eq $Node) { return $map }
    if ($Node -is [System.Collections.IDictionary]) {
        foreach ($k in @($Node.Keys)) { $map["$k"] = [int]$Node[$k] }
    }
    elseif ($Node -is [System.Management.Automation.PSCustomObject]) {
        foreach ($p in $Node.PSObject.Properties) { $map["$($p.Name)"] = [int]$p.Value }
    }
    else {
        # formato antiguo: un solo numero = timeout generico
        $n = 0; if ([int]::TryParse("$Node", [ref]$n)) { $map['default'] = $n }
    }
    if (-not $map.Contains('default')) { $map['default'] = 0 }
    return $map
}

function Resolve-CvConfigPathArg {
    <#
        Resuelve el argumento -Config de Convert.ps1/setup.ps1 a una ruta completa:
        vacio = <Root>\config.json; relativo = respecto al directorio actual; absoluto = tal cual.
    #>
    param([Parameter(Mandatory)][string]$Root, [string]$Config = '')
    if ([string]::IsNullOrWhiteSpace($Config)) { return (Join-Path $Root 'config.json') }
    if ([System.IO.Path]::IsPathRooted($Config)) { return $Config }
    return (Join-Path (Get-Location).Path $Config)
}

function Get-CvConfig {
    <#
        Carga config.json (si existe) sobre los valores por defecto, por secciones.
        Cualquier clave ausente en el json usa el valor por defecto (fusion profunda).
    #>
    param(
        [Parameter(Mandatory)][string]$Root,
        # Ruta explicita al config (parametro -Config de Convert/setup). Vacio = Root\config.json.
        [string]$Path = ''
    )
    $cfg = Get-CvConfigDefaults
    $path = if ([string]::IsNullOrWhiteSpace($Path)) { Join-Path $Root 'config.json' } else { $Path }
    if (Test-Path $path) {
        try {
            $json = Get-Content -Raw -Path $path | ConvertFrom-Json
            Merge-CvConfig -Default $cfg -Override $json
        } catch {
            Write-Host ("AVISO: config.json no valido, se usan valores por defecto ({0})" -f $_.Exception.Message) -ForegroundColor Yellow
        }
    }
    return $cfg
}

# ---------- ACCESO GENERICO A NODOS (PSCustomObject de ConvertFrom-Json e IDictionary) ----------

function Get-CvNodeKind($v) {
    if ($null -eq $v)                                        { return 'null' }
    if ($v -is [bool])                                       { return 'bool' }
    if ($v -is [string])                                     { return 'string' }
    if ($v -is [int] -or $v -is [long] -or $v -is [double] -or $v -is [single] -or $v -is [decimal]) { return 'number' }
    if ($v -is [System.Collections.IDictionary])             { return 'object' }
    if ($v -is [System.Management.Automation.PSCustomObject]){ return 'object' }
    if ($v -is [System.Collections.IEnumerable])             { return 'array' }
    return 'string'
}
function Get-CvNodeKeys($node) {
    if ($node -is [System.Collections.IDictionary]) { return @($node.Keys) }
    # Nota: en un PSCustomObject sin propiedades, .Name devuelve $null y @($null) daria una
    # clave fantasma; filtramos nulos/vacios para que un objeto vacio de 0 claves.
    if ($node) { return @($node.PSObject.Properties.Name | Where-Object { -not [string]::IsNullOrEmpty($_) }) }
    return @()
}
function Get-CvNodeVal($node, $key) {
    # La coma unaria evita que PowerShell desenvuelva un array de 1 elemento al retornar.
    if ($node -is [System.Collections.IDictionary]) { return , $node[$key] }
    return , $node.$key
}
function Set-CvNodeVal($node, $key, $value) {
    if ($node -is [System.Collections.IDictionary]) { $node[$key] = $value }
    else { $node.$key = $value }
}

# ---------- SERIALIZADOR JSON PROPIO (4 espacios, arrays de escalares en linea) ----------

function ConvertTo-CvJsonString([string]$s) {
    $e = $s.Replace('\','\\').Replace('"','\"').Replace("`r",'\r').Replace("`n",'\n').Replace("`t",'\t')
    return '"' + $e + '"'
}
function Format-CvNumber($n) {
    $inv = [System.Globalization.CultureInfo]::InvariantCulture
    if ($n -is [double] -or $n -is [single] -or $n -is [decimal]) { return ([double]$n).ToString($inv) }
    return ([long]$n).ToString($inv)
}
function ConvertTo-CvJson {
    param($Node, [int]$Indent = 0)
    $pad  = '    ' * $Indent
    $pad1 = '    ' * ($Indent + 1)
    switch (Get-CvNodeKind $Node) {
        'object' {
            $keys = @(Get-CvNodeKeys $Node)
            if ($keys.Count -eq 0) { return '{}' }
            $parts = @()
            foreach ($k in $keys) {
                $parts += ('{0}{1}: {2}' -f $pad1, (ConvertTo-CvJsonString "$k"), (ConvertTo-CvJson (Get-CvNodeVal $Node $k) ($Indent + 1)))
            }
            return "{`n" + ($parts -join ",`n") + "`n$pad}"
        }
        'array' {
            $items = @($Node)
            if ($items.Count -eq 0) { return '[]' }
            $allScalar = $true
            foreach ($it in $items) { if ((Get-CvNodeKind $it) -in @('object','array')) { $allScalar = $false; break } }
            if ($allScalar) {
                $vals = foreach ($it in $items) { ConvertTo-CvJson $it 0 }
                return '[' + ($vals -join ', ') + ']'
            }
            $parts = foreach ($it in $items) { $pad1 + (ConvertTo-CvJson $it ($Indent + 1)) }
            return "[`n" + ($parts -join ",`n") + "`n$pad]"
        }
        'bool'   { if ($Node) { return 'true' } else { return 'false' } }
        'number' { return (Format-CvNumber $Node) }
        'null'   { return 'null' }
        default  { return (ConvertTo-CvJsonString "$Node") }
    }
}

# ---------- APLICAR SOLO LOS CAMBIOS (para que el editor no reescriba todo config.json) ----------

function Get-CvChildNode {
    <# Devuelve el subnodo objeto $Node[$Key]; si no existe (o no es objeto) lo crea vacio. #>
    param($Node, [string]$Key)
    if ($Node -is [System.Collections.IDictionary]) {
        if (-not $Node.Contains($Key) -or (Get-CvNodeKind $Node[$Key]) -ne 'object') { $Node[$Key] = [ordered]@{} }
        return $Node[$Key]
    }
    if (-not $Node.PSObject.Properties[$Key]) { $Node | Add-Member -NotePropertyName $Key -NotePropertyValue ([pscustomobject]@{}) -Force }
    elseif ((Get-CvNodeKind $Node.$Key) -ne 'object') { $Node.$Key = [pscustomobject]@{} }
    return $Node.$Key
}

function Set-CvChildLeaf {
    <# Fija $Node[$Key] = $Value, creando la propiedad si falta (PSCustomObject o IDictionary). #>
    param($Node, [string]$Key, $Value)
    if ($Node -is [System.Collections.IDictionary]) { $Node[$Key] = $Value; return }
    if ($Node.PSObject.Properties[$Key]) { $Node.$Key = $Value }
    else { $Node | Add-Member -NotePropertyName $Key -NotePropertyValue $Value -Force }
}

function Remove-CvChild {
    <# Elimina la clave $Key de $Node (PSCustomObject o IDictionary). #>
    param($Node, [string]$Key)
    if ($Node -is [System.Collections.IDictionary]) { if ($Node.Contains($Key)) { $Node.Remove($Key) }; return }
    if ($Node.PSObject.Properties[$Key]) { $Node.PSObject.Properties.Remove($Key) }
}

function Update-CvConfigEdits {
    <#
        Aplica en $Target (config.json crudo) SOLO las hojas que cambiaron entre $Before y $Edited:
          - si el nuevo valor es IGUAL al default -> se ELIMINA de $Target (se usara el default).
          - si DIFIERE del default                -> se fija en $Target.
        Las hojas no editadas no se tocan (un config completo conserva lo no editado). Las
        secciones que quedan vacias tras eliminar se podan. Compara por serializacion JSON.
    #>
    param($Edited, $Before, $Default, $Target)
    $bkeys = @(Get-CvNodeKeys $Before)
    $dkeys = @(Get-CvNodeKeys $Default)
    foreach ($key in @(Get-CvNodeKeys $Edited)) {
        $ev = Get-CvNodeVal $Edited $key
        $bv = if ($bkeys -contains $key) { Get-CvNodeVal $Before $key } else { $null }
        # sin cambios respecto al inicio de la edicion -> no tocar
        if (($bkeys -contains $key) -and ((ConvertTo-CvJson $ev 0) -eq (ConvertTo-CvJson $bv 0))) { continue }

        $dv = if ($dkeys -contains $key) { Get-CvNodeVal $Default $key } else { $null }

        if ((Get-CvNodeKind $ev) -eq 'object' -and (Get-CvNodeKind $bv) -eq 'object') {
            # seccion con cambios dentro: recursar y podar si queda vacia
            $tchild = Get-CvChildNode -Node $Target -Key $key
            Update-CvConfigEdits -Edited $ev -Before $bv -Default $dv -Target $tchild
            if (@(Get-CvNodeKeys $tchild).Count -eq 0) { Remove-CvChild -Node $Target -Key $key }
        }
        elseif (($dkeys -contains $key) -and ((ConvertTo-CvJson $ev 0) -eq (ConvertTo-CvJson $dv 0))) {
            Remove-CvChild -Node $Target -Key $key      # volvio al default -> quitar del json
        }
        else {
            Set-CvChildLeaf -Node $Target -Key $key -Value $ev   # distinto del default -> guardar
        }
    }
}

# ---------- LECTURA / ESCRITURA DE config.json ----------

function Repair-CvConfigArrays($cfg) {
    <#
        PS 5.1 ConvertFrom-Json desenvuelve los arrays de 1 elemento a escalar (["es"] -> "es").
        Forzamos a array los campos que del esquema deben serlo (se editan como lista / [...] ).
    #>
    if ($cfg.languages) {
        if ($null -ne $cfg.languages.audio)    { $cfg.languages.audio    = @($cfg.languages.audio) }
        if ($null -ne $cfg.languages.subtitle) { $cfg.languages.subtitle = @($cfg.languages.subtitle) }
    }
    if ($cfg.downloads) {
        foreach ($p in $cfg.downloads.PSObject.Properties) {
            $app = $p.Value
            if ($null -ne $app.files)       { $app.files       = @($app.files) }
            if ($null -ne $app.versionArgs) { $app.versionArgs = @($app.versionArgs) }
            if ($null -ne $app.dependsOn)   { $app.dependsOn   = @($app.dependsOn) }
        }
    }
    if ($cfg.PSObject.Properties['profiles'] -and $null -ne $cfg.profiles) { $cfg.profiles = @($cfg.profiles) }
    if ($cfg.encode -and $null -ne $cfg.encode.extensions) { $cfg.encode.extensions = @($cfg.encode.extensions) }
}
function Read-CvConfigFile {
    param([Parameter(Mandatory)][string]$Path)
    $cfg = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
    Repair-CvConfigArrays $cfg
    return $cfg
}
function Save-CvConfigFile {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)]$Config)
    $json = (ConvertTo-CvJson -Node $Config -Indent 0) -replace "`n", "`r`n"
    [System.IO.File]::WriteAllText($Path, $json + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
}

function Reset-CvConfig {
    <#
        Restablece config.json a los valores por defecto, CONSERVANDO el catalogo de
        herramientas (seccion 'downloads' del config actual). Hace copia en <Path>.bak.
        Devuelve $true.
    #>
    param([Parameter(Mandatory)][string]$Path)
    if (Test-Path -LiteralPath $Path) {
        try { Copy-Item -LiteralPath $Path -Destination "$Path.bak" -Force } catch {}
        try {
            $cur = Read-CvConfigFile -Path $Path
        } catch { $cur = $null }
    }
    $def = Get-CvConfigDefaults
    if ($cur -and $cur.downloads) { $def['downloads'] = $cur.downloads }   # preservar herramientas
    Save-CvConfigFile -Path $Path -Config $def
    return $true
}

Export-ModuleMember -Function *
