reg add "HKLM\System\CurrentControlSet\services\tcpip\Parameters" /f /v "SearchList" /t REG_SZ /d "8.8.8.8"
reg add "HKLM\System\CurrentControlSet\services\tcpip\Parameters" /f /v "NV Domain" /t REG_SZ /d "8.8.8.8"
reg add "HKLM\System\CurrentControlSet\services\tcpip\Parameters" /f /v "Domain" /t REG_SZ /d "8.8.8.8"
reg add "HKLM\System\CurrentControlSet\services\tcpip\Parameters" /f /v "DhcpDomain" /t REG_SZ /d "8.8.8.8"
pause
