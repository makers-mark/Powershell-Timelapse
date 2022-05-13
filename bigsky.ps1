#clear

# Avoid SSL failures and use tls 1.2

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$debug             = $False    #  Debug = $True will not clear the screen, and will show ffmpeg debug information, and will try and gather images regardless of time.
$showFfmpegInDebug = $False
$numberOfImages    = "40"      #  When in debug mode, this number is how many images to capture before ending the loop and finishing by making a video out of (this) number of images.
$simulationOffset  = 0         #  This is just used for testing time frames ie. simulating it is a later or earlier time than it really is. It should be 0 except for testing.
$talk              = $False    #  Set to false to not use the voice statements

$darkSkyApi = "YOUR_DARK_SKY_API_KEY_HERE"

$videoBuildTime          = $False                    #  These are just some variable initializations to clear in ISE
$latency                 = 0
$timeAquired             = $False
$civilTwilightEndsTime   = $False
$civilTwilightBeginsTime = $False
$response                = $False

$disk              = "z:\"                           #  The next two vaviables are simply where to store the images and inherently the videos by these two variables
$dir               = "Bigsky"                        #  You do not want to mess this up and overwrite a disk or directory. KNOW WHAT YOU ARE DOING AND READ THE SCRIPT IF IN DOUBT.

$apiTempRate       = 25                              #  The temperature will be retrieved on the first image and reevaluated after every nth image. Depending on you account and camera latency you should set this number not to go over the 1000 free daily api requests.
$timeColor         = "red"
$temperatureColor  = "DodgerBlue"
$temperatureColor2 = "CornFlowerBlue"                #  This color is not used right now (for the time being) for the cooler summit temperature because of a recognizable disparity of color in the previous tighter proximity regarding the two temperature boxes.
$font              = "courbd.ttf"                    #  Font from the installed Windows fonts in "x:\Windows\Fonts\". This one is a nice constant width font that won't constantly make the shadow box constantly change its deminsions because the digits are changing exterior dimensions.
$dateFont          = "FTLTLT.TTF"
$titleFont         = "oldengl.ttf"

$textOpacity       = "0.75"                          #  Not used currently as I am still playing around with individual opacities for the different text fields.
$textBoxOpacity    = "0.80"                          #  Not used ever, yet as a variable for the same reason as in line 25.

$ffmpegLocation    = "z:\Bigsky\ffmpeg.exe"          #  Windows static builds are available at https://ffmpeg.zeranoe.com/builds/
$frameRate         = "25"                            #  To each their own.
$imageType         = "jpg"
$resolution        = "1920x1080"

$timeZone          = "Mountain Standard Time"        #  This is the time zone where the camera is located at.
                                                     #  If you do not get this string correct, everything may fail if it is not listed or you may get the string right and end up with an incorrect time (from experience).
                                                     #  Open a Powershell prompt and run the cmdlet "Get-TimeZone -ListAvailable" and then pick the correct time zone string.

$uri               = "http://76.75.8.117/jpg/image.jpg?resolution=$resolution&compression=0"      #  This is your cameras fqdn address as well as all of the extraneous information. I use an ip address to avoid a DNS lookup (even though it is typically cached) by Windows.
                                                                                                  #  If you do not know the ip address but know the fqdn just open and cmd prompt and type "ping -4 -a `fqdn`", but replace "fqdn" with your url. example: ping -4 -a webcam01.bigskyresort.com

[string]$lat               = "45.284444"
[string]$lng               = "-111.4008333"
[string]$loneMountainLat   = "45.278299"
[string]$loneMountainLng   = "-111.450590"

function Get-DateOrdinalSuffix([datetime]$Date) {

    switch -regex ($Date.Day.ToString()) {

        '1(1|2|3)$' { 'th'; break }
        '.?1$'      { 'st'; break }
        '.?2$'      { 'nd'; break }
        '.?3$'      { 'rd'; break }
        default     { 'th'; break }

    }

}

if($talk){

    Add-Type -AssemblyName System.speech
    Write-Verbose "Creating Speech object"
    $say = New-Object System.Speech.Synthesis.SpeechSynthesizer
    $say.SelectVoice('Microsoft Zira Desktop')

}

if($debug){

    $progressPreference = 'continue'

    if($showFfmpegInDebug){

        $logLevel           = "verbose"
        $hideBanner         = ""
    } else {

        $logLevel           = "quiet"
        $hideBanner         = "-hide_banner"
        
    }

} else {

    # Do not show the status of downloading the images using Invoke-WebRequest and tell ffmpeg to not show every status point as well as hiding the installed compilation options in the banner.

    $progressPreference = 'silentlyContinue'
    $logLevel           = "quiet"
    $hideBanner         = "-hide_banner"

}

# Other Ip Cameras

# http://200.79.225.83:8080/jpg/image.jpg?compression=0&resolution=1920x1080   Cancun MX   21.174290, -86.846560
# http://70.33.15.178:8084/jpg/image.jpg?resolution=1280x720&compression=0     Bozeman MT
# http://69.51.121.170/jpg/image.jpg?resolution=1280x720&compression=0         Kalispell MT
# http://162.245.149.144/jpg/image.jpg?compression=0&resolution=1920x1080      Colorado Springs, CO
# http://68.228.20.16:82/bitmap/image.bmp?resolution=1280x720&compression=0    Wilmington Beach
# http://24.246.176.7/jpg/image.jpg?resolution=1280x720&compression=0          Asheville NC
# http://204.10.182.2:1024/jpg/image.jpg?compression=0                         Ocala Fla
# http://67.162.158.218:8080/jpg/image.jpg?resolution=1280x720&compression=0   Dillon US
# http://201.134.110.102:8000/jpg/image.jpg?resolution=1280x720&compression=0  San Jose Del Cabo Mexico

# Set the folders up and suppress the uninformative output via Out-Null

new-item -Force -Path $disk$dir        -ItemType directory | Out-Null
new-item -Force -Path $disk$dir\videos -ItemType directory | Out-Null
new-item -Force -Path $disk$dir\images -ItemType directory | Out-Null

do{                  # This do loop encompasses the entire rest of the script and is meant to run forever. My infinite loop paradigm.

    do{              # This one runs until the okay is given and the civil twilight times have been aquired for the location and it is time to start connecting to the camera

    $dateToday    = $(Get-Date).ToString("yyyy-MM-dd")
    $dateTommorow = $(Get-Date).AddDays(1).ToString("yyyy-MM-dd")
    $now          = ([System.DateTime]::UtcNow).AddHours($simulationOffset)

        try{ 

            $jsonResponse = Invoke-WebRequest -UseBasicParsing https://api.sunrise-sunset.org/json?lat=$lat"&"lng=$lng"&"date=$dateToday"&"formatted=0
            $response     = ConvertFrom-Json -InputObject $jsonResponse

        }catch{

            # No response or maybe not even sent

            Write-Host "Error getting sunrise and sunset from the API webrequest."
            Write-Host $_.Exception
            start-sleep -s 30
            $timeAquired = $False
            $response    = $False
        
        }    

        # I had to convert the API response to UTC even though it is supposed to be a UTC response per the documentation 
    
        if($response){$civilTwilightBeginsTime = $(Get-Date -Date $response.results.civil_twilight_begin).ToUniversalTime()}

        if($response){$civilTwilightEndsTime   = $(Get-Date -Date $response.results.civil_twilight_end).ToUniversalTime()}
  
        if($response -and ($now -gt $civilTwilightEndsTime)){        # It is past "dusk" today, so request the civil twilight begin time for tommorow from the sunrise sunset api
             
            $response = $False
                      
            try{
  
                $jsonResponse = Invoke-WebRequest -UseBasicParsing https://api.sunrise-sunset.org/json?lat=$lat"&"lng=$lng"&"date=$dateTommorow"&"formatted=0
                $response     = ConvertFrom-Json -InputObject $jsonResponse
                
            }catch{

                Write-Host "Error getting sunrise and sunset for tommorrow."
                Write-Host $_.Exception
                Start-Sleep -s 30
                $timeAquired = $False
                $response    = $False

            }

            if($response){$civilTwilightBeginsTime = $(Get-Date -Date $response.results.civil_twilight_begin).ToUniversalTime()}
            if($response){$civilTwilightEndsTime   = $(Get-Date -Date $response.results.civil_twilight_end).ToUniversalTime()}

            #Write-Host "The new begin time is $civilTwilightBeginsTime"
            #Write-Host "The new end time is $civilTwilightEndsTime"
                                    
            $sleepSeconds        = (New-TimeSpan $now $civilTwilightBeginsTime).TotalSeconds
            $sleepUntilLocalTime = $(Get-Date).AddSeconds($sleepSeconds).addhours($simulationOffset).ToString("hh:mm:ss tt MM-dd-yy").TrimStart("0")         
                    
            if($videoBuildTime){

                #Get-FileMetaData -Files "$disk$dir\videos\$dateFolderName.mkv"
                        
                write-host "The last video created was $i frames long and took"
                write-Host "$videoBuildTime to build."
                Write-Host "It is located @ $disk$dir\videos\$dateFolderName.mkv"
                Write-Host "There were $failures camera request failures."
                write-host "The average network/camera latency was $latency ms."
            }

            if($talk){$say.SpeakAsync("Sleeping until $sleepUntilLocalTime")}

            if($response -ne $False){
            
                $timeAquired = $True

                Write-Host "_____________________________________________________________"
                write-host "Sleeping until $sleepUntilLocalTime local time"
                sleep -seconds $sleepSeconds
            }

        }elseif($response -and ($now -gt $civilTwilightBeginsTime) -and ($now -lt $civilTwilightEndsTime)){

            $timeAquired = $True

        }elseif($response -and ($now -lt $civilTwilightBeginsTime)){
                
            $sleepSeconds            = (New-TimeSpan $now $civilTwilightBeginsTime).TotalSeconds
            $sleepUntilLocalTime     = $(Get-Date).addhours($simulationOffset).AddSeconds($sleepSeconds).ToString("hh:mm:ss tt MM-dd-yy").TrimStart("0")         
                    
            if($videoBuildTime){

                #Get-FileMetaData -Files "$disk$dir\videos\$dateFolderName.mkv"           
                write-host "The last video created was $i frames long and took"
                write-Host "$videoBuildTime to build."
                Write-Host "It is located @ $disk$dir\videos\$dateFolderName.mkv"
                Write-Host "There were $failures camera request failures."
                write-host "The average network/camera latency was $latency ms."
            }

            $timeAquired = $True

            if($talk){$say.SpeakAsync("Sleeping until $sleepUntilLocalTime")}

            Write-Host "_____________________________________________________________"
            write-host "Sleeping until $sleepUntilLocalTime local time"
            sleep -seconds $sleepSeconds

        }else{
        
            Write-Host "There is an error somewhere. Sleeping for 30 seconds then trying the sunrise sunset api request again."
            Write-Host "Make sure that your $lat and $lng variables for the query are a [string] and in decimal gps coordinates (not degrees, minutes, seconds...)"
 
            sleep -Seconds 30
        
        }            

    }until($timeAquired)

    if($talk){$say.Speak("Image gathering has commenced.")}

    $i = 0
    $x = 0
    [int]$failures  = 0

    $dateFolderName = $((Get-Date).addhours($simulationOffset).ToString('MM-dd-yyyy_hh_mm_ss_tt'))

    $titleDateStamp = Get-Date
    $suffix         = Get-DateOrdinalSuffix $titleDateStamp
    $titleDateStamp = "{0} {1:MMMM} {2}{3}, {4}" -f $titleDateStamp.DayOfWeek, $titleDateStamp, $titleDateStamp.Day, $suffix, $titleDateStamp.Year

    new-item -Force -Path $disk$dir\images\$dateFolderName -ItemType directory | Out-Null
       
    $timeStarted = ([System.DateTime]::UtcNow).addhours($simulationOffset)
    $timeToEnd   = $civilTwilightEndsTime

    do{

        # Get the temperatures at the two different locations with two api queries. Only do this on the second image and every 25th after that.
        # Since I started my incrimenter $i at 0, this "and/or" statement is necessary when doing the modulous operator because 0 % {$anyNumber} equals 0.
        # So if the camera is down or the web-request fails $i will still be 0 because it has to be decremented since there was no image returned.
        # Without this "and/or" the way it is, that would lead to race condition polling the weather API

        if(($i -eq 1) -or (($i -ne 0) -and ($i % $apiTempRate -eq 0))){

            try{

                # Get the temperature at the camera position as well as the Lone Mountain summit to display on the image.
                    
                    # This works below, but I use a potentially better api service now
                    
                    #$jsonResponse = Invoke-WebRequest -UseBasicParsing https://api.openweathermap.org/data/2.5/weather?lat=45.284444"&"lon=-111.4008333"&"units=imperial"&"APPID=USE_YOURS
                    
                    Write-Host "Getting Temperatures from the darksky api"
                    
                    $jsonResponse            = Invoke-WebRequest -UseBasicParsing "https://api.darksky.net/forecast/$darkSkyApi/$lat,$lng`?exclude=minutely,hourly,daily,alerts,flags"
                    $response                = ConvertFrom-Json -InputObject $jsonResponse
                    $temperature             = [math]::Round($response.currently.temperature)
                    
                    $jsonResponse            = Invoke-WebRequest -UseBasicParsing "https://api.darksky.net/forecast/$darkSkyApi/$loneMountainLat,$loneMountainLng`?exclude=minutely,hourly,daily,alerts,flags"
                    $response                = ConvertFrom-Json -InputObject $jsonResponse
                    $loneMountainTemperature = [math]::Round($response.currently.temperature)

                    if($talk -and ($i -eq 1)){
                    
                        $say.SelectVoice('Microsoft David Desktop')
                        $say.SpeakAsync("The current temperature at the Big Sky Resort is $temperature degrees, the temperature on Lone Mountain is $loneMountainTemperature degrees.")
                        $say.SelectVoice('Microsoft Zira Desktop')
                    }
                       
            }catch{

                    Write-Host "Error getting temperatures."
                    Write-Host "Check your APPID."
                    $loneMountainTemperature = 0;
                    $temperature             = 0;

            }

        }

        # Handle the local time stamp text for the video and remove the zero in front of single digit hours

        $i++

        $textTime = (Get-Date).addhours($simulationOffset)
        $textTime = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($textTime, [System.TimeZoneInfo]::Local.Id, $timeZone).ToString('hh\\:mm tt').TrimStart('0')
    
        $timeNow          = ([System.DateTime]::UtcNow).addhours($simulationOffset)
        [string]$timeLeft = ($timeToEnd - $timeNow)
        $timeLeft         = $timeLeft.Substring(0, $timeLeft.LastIndexOf('.')).trimstart('0:')

        #write-host $titleDateStamp

        if($debug){

            $imagesLeft = $numberOfImages - $i
            Write-Host "Images left: $imagesLeft"

        }else{

            Write-Host "Time left---> $timeLeft"

        }


        Write-Host "Image: $i"
        Write-Host "Lone Mountain Temperature is $loneMountainTemperature"
        write-host "Resort Temperature is $temperature"
        Write-Host "_______________________________________"

        if($latency){

            Write-Host "Average Camera Latency: $latency ms"

        }

        Write-Host "Camera Request Failures: $failures"

        # Wrap the request in a try catch block to avoid misnumbered images over a span of time as this will fail when putting the images back together with ffmpeg
            
        
        try{
                  
            $x += Measure-Command{
                
                Invoke-WebRequest $uri -OutFile $disk$dir\images\$dateFolderName\image$i.$imageType
                
            }

            $latency = ([int]$x.totalMilliseconds/[int]$i)
            
            # This ffmpeg command that is commented out works. But adds a little more processing time by adding the "Powered By Dark Sky" png, during the gathering of images cycle.
            # Instead, I add the logos at the end when the video is being put together and the system is no longer gathering images.

            #& $ffmpegLocation -hide_banner -loglevel quiet -y -i $disk$dir\images\$dateFolderName\image$i.$imageType -i $disk$dir\poweredby.png -filter_complex "[0:v][1:v]overlay=1730:0, drawtext=fontfile=c\\:/windows/fonts/courbd.ttf:fontsize=48:x=10:y=1040:fontcolor=red@0.75:shadowx=1:shadowy=1:box=1:boxcolor=0x00000000@0.80:boxborderw=5:text='$textTime', drawtext=fontfile=c\\:/windows/fonts/courbd.ttf:fontsize=36:x=10:y=980:fontcolor=DodgerBlue@0.85:shadowx=1:shadowy=1:box=1:boxcolor=0x00000000@0.80:boxborderw=5:text='$temperature°', drawtext=fontfile=c\\:/windows/fonts/courbd.ttf:fontsize=18:x=8:y=1017:fontcolor=CornFlowerBlue@0.85:box=1:boxcolor=0x00000000@0.80:boxborderw=3:text='$loneMountainTemperature° on the summit'" $disk$dir\images\$dateFolderName\image$i.$imageType
                
            & $ffmpegLocation $hideBanner -loglevel $logLevel -y -i $disk$dir\images\$dateFolderName\image$i.$imageType -vf drawtext="fontfile=c\\:/windows/fonts/$font :fontsize=60:x=10:y=1032:fontcolor=$timeColor@0.85:shadowx=1:shadowy=1:box=1:boxcolor=0x00000000@0.80:boxborderw=5:text='$textTime', drawtext=fontfile=c\\:/windows/fonts/$font :fontsize=36:x=10:y=987:fontcolor=$temperatureColor@0.85:shadowx=1:shadowy=1:box=1:boxcolor=0x00000000@0.80:boxborderw=5:text='Village $temperature°', drawtext=fontfile=c\\:/windows/fonts/$font :fontsize=36:x=10:y=949:fontcolor=$temperatureColor2@0.85:shadowx=1:shadowy=1:box=1:boxcolor=0x00000000@0.80:boxborderw=5:text='Summit  $loneMountainTemperature°'" $disk$dir\images\$dateFolderName\image$i.$imageType
                
            # Option to sleep for a certain number of seconds before continuing and requesting another image from the camera.               
            # I currently have the start-sleep command commented out due to the latency getting the image from the camera in the first place.

            #start-sleep -s 3

        }catch{

            # The request failed, or less likely ffmpeg failed, so the incrementer has to be dealt with or ffmpeg will instantly stop when it gets to a break in the image%d sequence of numbers
            
            Write-Host "The webrequest to the camera has failed."
            $failures++
            $i--

        }

        if($debug -ne $True){
            
            clear
            
        }

    #Change the order of operations in the while tommorow

    }while (($debug -and ($i -le $numberOfImages)) -or ($debug -eq $False -and ($timeNow -lt $timeToEnd)))

    if($talk){$say.SpeakAsync("Image grabbing has ended, making a time lapse video now.")}

    # Now that the image grabbing sequence is done, put the images together into an mkv video and add the "Powered by Dark Sky" logo.

    $videoBuildTime = Measure-Command{
       
       # These two below were older ffmpeg commands to build the video before I started adding logos and titles.

       # & $ffmpegLocation -y $hideBanner -framerate $frameRate -start_number 1 -i $disk$dir\images\$dateFolderName\image%d.$imageType -i $disk$dir\poweredby.png -crf 18 -filter_complex "[0:v][1:v]overlay=1730:0" -preset slow -pix_fmt yuv420p -s $resolution -vcodec libx264 $disk$dir\videos\$dateFolderName.mkv
       # & ffmpeg -y $hideBanner -framerate $frameRate -start_number 1 -i $disk$dir\images\$dateFolderName\image%d.jpg -i $disk$dir\poweredby.png -crf 18 -filter_complex "[0:v][1:v]overlay=1730:0, drawtext=fontfile=c\\:/windows/fonts/$dateFont :fontsize=60:x=(w-text_w)/2:y=((h-text_h)/2)-180:enable=between(t\,1\,4):fontcolor=0xa5a6fe@0.80:shadowx=5:shadowy=5:boxborderw=5:text=$titleDateStamp :box=1:boxcolor=0x00000000@0.30:boxborderw=10, drawtext=fontfile=c\\:/windows/fonts/$titleFont :fontsize=72:x=(w-text_w)/2:y=((h-text_h)/2)-190:enable=between(t\,5\,11):fontcolor=0x715efd@0.90:shadowx=6:shadowy=6:text='Big Sky Resort', drawtext=fontfile=c\\:/windows/fonts/$titleFont :fontsize=74:x=(w-text_w)/2:y=((h-text_h)/2)-110:enable=between(t\,5\,11):fontcolor=0x715efd@0.90:shadowx=6:shadowy=6:text='Montana'" -preset slow -s $resolution -vcodec libx264 $disk$dir\videos\$dateFolderName.mkv
         
         & $ffmpegLocation -y -thread_queue_size 512 -framerate $frameRate -start_number 1 -i $disk$dir\images\$dateFolderName\image%d.jpg -i $disk$dir\poweredby.png -crf 18 -filter_complex "drawtext=fontfile=c\\:/windows/fonts/oldengl.ttf :fontsize=72:x=(w-text_w)/2:y=((h-text_h)/2)-190:enable=between(t\,1\,6):fontcolor=0x715efd@0.90:shadowx=2:shadowy=2:text='The Big Sky Resort',drawtext=fontfile=c\\:/windows/fonts/oldengl.ttf :fontsize=74:x=(w-text_w)/2:y=((h-text_h)/2)-110:enable=between(t\,1.1\,6):fontcolor=0x715efd@0.90:shadowx=2:shadowy=2:text='Montana',fade=t=in:start_time=1:d=0.5:alpha=1,fade=t=out:start_time=5.75:d=0.25:alpha=1[fg];[0:v][fg]overlay=format=auto[logo], [logo][1:v]overlay=1730:0,drawtext=fontfile=c\\:/windows/fonts/$dateFont :fontsize=60:x=(w-text_w)/2:y=((h-text_h)/2)+180:enable=between(t\,7\,11):fontcolor=0xa5a6fe@0.85:shadowx=1:shadowy=1:boxborderw=3:text='$titleDateStamp':box=1:boxcolor=0x00000000@0.60:boxborderw=10" -preset fast -s $resolution -vcodec libx264 $disk$dir\videos\$dateFolderName.mkv    
 
    }

    if($talk){$say.Speak("The video is done processing.")}

#ffmpeg -y $hideBanner -framerate $frameRate -start_number 1 -i $disk$dir\images\$dateFolderName\image%d.jpg -i $disk$dir\poweredby.png -crf 18 -filter_complex "[0:v][1:v]overlay=1730:0, drawtext=fontfile=c\\:/windows/fonts/$dateFont :fontsize=60:x=(w-text_w)/2:y=((h-text_h)/2)-180:enable=between(t\,1\,4):fontcolor=0xa5a6fe@0.80:shadowx=5:shadowy=5:boxborderw=5:text='Saturday October 25th, 2018':box=1:boxcolor=0x00000000@0.30:boxborderw=10, drawtext=fontfile=c\\:/windows/fonts/$titleFont :fontsize=72:x=(w-text_w)/2:y=((h-text_h)/2)-190:enable=between(t\,5\,11):fontcolor=0x715efd@0.90:shadowx=6:shadowy=6:text='Big Sky Resort', drawtext=fontfile=c\\:/windows/fonts/$titleFont :fontsize=74:x=(w-text_w)/2:y=((h-text_h)/2)-110:enable=between(t\,5\,11):fontcolor=0x715efd@0.90:shadowx=6:shadowy=6:text='Montana'" -preset slow -s $resolution -vcodec libx264 $disk$dir\videos\$dateFolderName.mkv

#Now with title that fades in and out
#$ $ffmpegLocation -y -thread_queue_size 512 -framerate $frameRate -start_number 1 -i $disk$dir\images\$dateFolderName\image%d.jpg -i $disk$dir\poweredby.png -crf 18 -filter_complex "drawtext=fontfile=c\\:/windows/fonts/oldengl.ttf :fontsize=72:x=(w-text_w)/2:y=((h-text_h)/2)-190:enable=between(t\,1\,6):fontcolor=0x715efd@0.90:shadowx=4:shadowy=4:text='Big Sky Resort',drawtext=fontfile=c\\:/windows/fonts/oldengl.ttf :fontsize=74:x=(w-text_w)/2:y=((h-text_h)/2)-110:enable=between(t\,1\,6):fontcolor=0x715efd@0.90:shadowx=4:shadowy=4:text='Montana',fade=t=in:start_time=1:d=0.5:alpha=1,fade=t=out:start_time=5.75:d=0.25:alpha=1[fg];[0:v][fg]overlay=format=auto[logo], [logo][1:v]overlay=1730:0,drawtext=fontfile=c\\:/windows/fonts/$dateFont :fontsize=60:x=(w-text_w)/2:y=((h-text_h)/2)-180:enable=between(t\,8\,11):fontcolor=0xa5a6fe@0.80:shadowx=5:shadowy=5:boxborderw=5:text=$titleDateStamp:box=1:boxcolor=0x00000000@0.30:boxborderw=10" -preset fast -s $resolution -vcodec libx264 $disk$dir\videos\$dateFolderName.mkv

if($debug){return}                   # Don't keep looping after the number of images under debug is met.

}While (1)
