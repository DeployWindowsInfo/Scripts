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
    $AppID = ((Get-StartApps -Name 'Windows Powershell') | Select -First 1).AppId;
    New-Item "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings\$AppID" -Force | Out-Null
    Set-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings\$AppID" `
        -Name "ShowInActionCenter" -Type Dword -Value "1" -Force | Out-Null

    # Create and show the toast, dont forget AppId
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppID).Show($Toast);
}

# Example images from https://picsum.photos/
ShowToast -Image "https://picsum.photos/150/150?image=1060" -ToastTitle "title" `
    -ToastText "Text generated: $([DateTime]::Now.ToShortTimeString())" -ToastDuration short;

