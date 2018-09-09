#Install Chocolately
iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

Install-PackageProvider -Name NuGet -Force
find-module -Repository PSGallery -Name PowerShellGet | Install-Module -Force
find-module -Repository PSGallery -Name PSScriptAnalyzer | Install-Module -Force
find-module -Repository PSGallery -Name Pester | Install-Module -Force -SkipPublisherCheck

