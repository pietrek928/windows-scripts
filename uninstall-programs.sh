PROGRAMS="
3dbuilder
windowsalarms
Appconnector
windowscalculator
windowscommunicationsapps
windowscamera
CandyCrushSaga
CandyCrushSodaSaga
officehub
skypeapp
getstarted
zunemusic
windowsmaps
Messaging
solitairecollection
bingfinance
zunevideo
bingnews
onenote
CommsPhone
windowsphone
photos
WindowsScan
bingsports
windowsstore
Office.Sway
Twitter
soundrecorder
bingweather
xboxapp
XboxOneSmartGlass
"

for p in $PROGRAMS
do
    echo "powershell -command \"Get-appxpackage -allusers *${p}* | Remove-AppxPackage\""
done

