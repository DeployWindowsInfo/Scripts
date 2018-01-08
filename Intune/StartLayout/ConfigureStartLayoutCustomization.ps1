﻿
function ShowToast {
    param(
        [parameter(Mandatory=$true,Position=1)]
        [string] $Image,
        [parameter(Mandatory=$true,Position=2)]
        [string] $ToastTitle,
        [parameter(Mandatory=$true,Position=3)]
        [string] $ToastText,
        [parameter()]
        [ValidateSet('long','short')]
        [string] $ToastDuration = "long"
    )

    # Toast overview: https://msdn.microsoft.com/en-us/library/windows/apps/hh779727.aspx
    # Toasts templates: https://msdn.microsoft.com/en-us/library/windows/apps/hh761494.aspx
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null

    # Download or define a local image file://c:/image.png
    # Toast images must have dimensions =< 1024x1024 size =< 200 KB
    if ($Image -match "http*") {
        [System.Reflection.Assembly]::LoadWithPartialName("System.web") | Out-Null
        $Image = [System.Web.HttpUtility]::UrlEncode($Image);
        $imglocal = "$($env:TEMP)\ToastImage.png";
        Start-BitsTransfer -Destination $imglocal -Source $([System.Web.HttpUtility]::UrlDecode($Image)) -ErrorAction Continue;
    } else {
        $imglocal = $Image;
    }

    # Define the toast template and create variable for XML manipuration
    # Customize the toast title, text, image and duration
    $toastXml = [xml] $([Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent(`
        [Windows.UI.Notifications.ToastTemplateType]::ToastImageAndText02)).GetXml();
    $toastXml.GetElementsByTagName("text")[0].AppendChild($toastXml.CreateTextNode($ToastTitle)) | Out-Null
    $toastXml.GetElementsByTagName("text")[1].AppendChild($toastXml.CreateTextNode($ToastText)) | Out-Null
    $toastXml.GetElementsByTagName("image")[0].SetAttribute("src", $imglocal);
    $toastXml.toast.SetAttribute("duration", $ToastDuration);

    # Convert back to WinRT type
    $xml = New-Object Windows.Data.Xml.Dom.XmlDocument; $xml.LoadXml($toastXml.OuterXml);
    $toast = [Windows.UI.Notifications.ToastNotification]::new($xml);

    # Get an unique AppId from start, and enable notification in registry
    if ([System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value.ToString() -eq "S-1-5-18") {
      #Popup alternative when running as system
      $wshell = New-Object -ComObject Wscript.Shell
      if ($ToastDuration -eq "long") { 
        $return = $wshell.Popup($ToastText,10,$ToastTitle,0x100)
      } else { 
        $return = $wshell.Popup($ToastText,4,$ToastTitle,0x100)
      }

    } else {
      $AppID = ((Get-StartApps -Name 'Windows Powershell') | Select -First 1).AppId;
      New-Item "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings\$AppID" -Force | Out-Null
      Set-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings\$AppID" `
          -Name "ShowInActionCenter" -Type Dword -Value "1" -Force | Out-Null
      # Create and show the toast, dont forget AppId
      [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppID).Show($Toast);
    }
}


$ScheduledScript = 'Start-Transcript -Path c:\Temp\Log.txt -Append
  $UserProfile = Get-WmiObject -Class Win32_UserProfile -ComputerName Localhost -Filter "LocalPath=''c:\\Users\\Mattias''"
  $UserProfile.Delete()
  $LayoutModification = ''<LayoutModificationTemplate xmlns:defaultlayout="http://schemas.microsoft.com/Start/2014/FullDefaultLayout" xmlns:start="http://schemas.microsoft.com/Start/2014/StartLayout" Version="1" xmlns="http://schemas.microsoft.com/Start/2014/LayoutModification">
  <LayoutOptions StartTileGroupCellWidth="6" /><DefaultLayoutOverride LayoutCustomizationRestrictionType="OnlySpecifiedGroups">
    <StartLayoutCollection><defaultlayout:StartLayout GroupCellWidth="6">
        <start:Group Name="customizations">
			<start:Tile AppUserModelID="Microsoft.MicrosoftEdge_8wekyb3d8bbwe!MicrosoftEdge"
                Size="2x2" Row="0" Column="0"/>
        </start:Group></defaultlayout:StartLayout></StartLayoutCollection></DefaultLayoutOverride></LayoutModificationTemplate>'';
  #$LayoutModification | Out-File -FilePath "C:\users\default\appdata\Local\Microsoft\windows\shell\LayoutModification.xml"
  #$LayoutModification | Out-File -FilePath "C:\Temp\Test.xml"
Stop-Transcript';


$ScheduledTask = [xml]'<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Date>2018-01-08T11:48:32.0828544</Date>
    <Author>Administrator</Author>
    <URI>\Create Start</URI>
  </RegistrationInfo>
  <Triggers>
    <BootTrigger>
      <Enabled>true</Enabled>
    </BootTrigger>
    <SessionStateChangeTrigger>
      <Enabled>true</Enabled>
      <StateChange>ConsoleDisconnect</StateChange>
    </SessionStateChangeTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>S-1-5-18</UserId>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>true</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>true</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>false</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>true</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <DisallowStartOnRemoteAppSession>false</DisallowStartOnRemoteAppSession>
    <UseUnifiedSchedulingEngine>true</UseUnifiedSchedulingEngine>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT72H</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>-ExecutionPolicy ByPass "c:\Temp\Startup.ps1"</Arguments>
    </Exec>
  </Actions>
</Task>';

New-Item -ItemType Directory -Path C:\Temp -Force | Out-Null
$ScheduledScript | Out-File -FilePath "C:\Temp\Startup.ps1" -Force
Register-ScheduledTask -Xml $ScheduledTask.OuterXml  -TaskName "Remove Profile"

# Example images from https://picsum.photos/
ShowToast -Image "https://picsum.photos/150/150?image=1060" -ToastTitle "Profile script installed" `
    -ToastText "Text generated: $([DateTime]::Now.ToShortTimeString())" -ToastDuration short;
