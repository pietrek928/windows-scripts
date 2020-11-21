NET_SVCS="
Dhcp Dnscache netprofm NlaSvc nsi Wcmsvc WinHttpAutoProxySvc
"
HW_SVCS="
PlugPlay DsmSvc ShellHWDetection
"
PRINT_SVCS="
Spooler LanmanServer
"
AUDIO_SVCS="
AudioEndpointBuilder Audiosrv
"
WSTORE_SVCS="

"

DISABLE_SERVICES="
BthAvctpSvc DPS WdiServiceHost WdiSystemHost
DispBrokerDesktopSvc TrkWks MapsBroker lfsvc gpsvc iphlpsvc wlidsvc
NcbService OneSyncSvc_2a83e SEMgrSvc PimIndexMaintenanceSvc_2a83e Power
PcaSvc RasMan SessionEnv TermService UmRdpService RetailDemo SstpSvc
wscsvc SSDPSRV SgrmBroker UnistoreSvc_2a83e UsoSvc upnphost LanmanWorkstation
SecurityHealthService WpnService LicenseManager mpssvc WinDefend WSearch
WbioSrvc $PRINT_SVCS $AUDIO_SVCS
"
# BrokerInfrastructure DcomLaunch
MANUAL_SERVICES="
BITS BFE EventSystem VaultSvc CryptSvc
RpcSs RpcEptMapper SamSs sppsvc StateRepository SENS SystemEventsBroker Schedule
Winmgmt FontCache EventLog ClipSVC AppXSvc
"

cat << EOF
Windows Registry Editor Version 5.00

EOF

for s in $DISABLE_SERVICES ;
do
cat << EOF
[HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Services\\$s]
"Start"=dword:00000004

EOF
done

for s in $MANUAL_SERVICES ;
do
cat << EOF
[HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Services\\$s]
"Start"=dword:00000003

EOF
done

