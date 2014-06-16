# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
#                                                                                                                           
# 																															Stephane van Gulick / PowerShellDistrict.Com
# 																															Rikard Ronnkvist / snowland.se
#																															Michael Niehaus / http://blogs.technet.com/mniehaus
#  Usage:
#   Save the file as SCCM-Commands.psm1
#   PS:>Import-Module SCCM-Commands
#   PS:>Get-SCCMCommands
#
#  Current Version : 2.0
#
#  History:
#
#  2009-04-07   Michael Niehaus     Original code posted at http://blogs.technet.com/mniehaus/
#  2010-03-10   Rikard Ronnkvist    Major makeover and first snowland.se release (Version 1.0)
#  ...
#  2013-11-13	Stéphane van Gulick Major update: Version 2.0 (Added around 50 new Functions).
#  2013-11-13	Stéphane van Gulick New Functions:[Software Update Packages]: Get-SCCMSoftwareUpdatesGroup, Get-SCCMSoftwareUpdate, New-SCCMSoftwareUpdatePackage, Remove-SCCMSoftwareUpdatePackage,Add-SCCMSoftwareUpdateToSoftwareUpdatePackage, Remove-SCCMSoftwareUpdateFromSoftwareUpdatePackage, Get-SCCMSoftwareUpdatesPackageSourcePath
#  									New Functions:[Software Update Lists] : Get-SCCMSoftwareUpdateList, Update-SCCMSoftwareUpdateList, New-SCCMSoftwareUpdateList,Remove-SCCMSoftwareUpdateList
# 									New Functions:[Software Update Deployments] : Get-SCCMSoftwareUpdateDeployment, New-SCCMSoftwareUpdateDeployment, Remove-SCCMSoftwareUpdateDeployment
#  2014-01-01	Stéphane van Gulick New Functions:[Task Sequence Packages] : Get-SccmTaskSequencePackage, Get-SCCMTaskSequenceRelatedPackages
# 									New Functions:[Task Sequence] : Export-SCCMTaskSequence, Import-SCCMTaskSequencePackage
#  2014-01-01	Stéphane van Gulick New Functions:[Drivers] : New-SCCMDriver, Add-SCCMDriversToBootImage, Get-SCCMDriver, 
#  2014-01-01						New Functions:[DriverPackage] :Add-SCCMDriverToDriverPackage, Get-SCCMDriverPackage, Update-DriverPackage
#  2014-01-01	Stéphane van Gulick	New Functions:[Folders] : Get-SCCMFolder, New-SCCMFolder, Remove-SCCMFolder, Move-SCCMFolderContent
#  2014-01-01						New Functions:[ComputerAssociation] : Get-SCCMComputerAssociation, New-SCCMComputerAssociation, Remove-SCCMComputerAssocation
#  2014-01-01						New Functions:[Helper functions] : Convert-WMITime, ConvertFrom-WMITime, Get-ContentID, Convert-SQLTimeToWMITime
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

#--------------------------------------Version 1.0-------------------------

#Region BaseCommands

Function Get-SCCMCommands {
    # List all SCCM-commands
    [CmdletBinding()]
    PARAM ()
    PROCESS {
        return Get-Command -Name *-SCCM* -CommandType Function  | Sort-Object Name | Format-Table Name, Module
    }
}
 
Function Connect-SCCMServer {
    # Connect to one SCCM server
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$false,HelpMessage="SCCM Server Name or FQDN",ValueFromPipeline=$true)][Alias("ServerName","FQDN","ComputerName")][String] $HostName = (Get-Content env:computername),
        [Parameter(Mandatory=$false,HelpMessage="Optional SCCM Site Code",ValueFromPipelineByPropertyName=$true )][String] $siteCode = $null,
        [Parameter(Mandatory=$false,HelpMessage="Credentials to use" )][System.Management.Automation.PSCredential] $credential = $null
    )
 
    PROCESS {
        # Get the pointer to the provider for the site code
        if ($siteCode -eq $null -or $siteCode -eq "") {
            Write-Verbose "Getting provider location for default site on server $HostName"
            if ($credential -eq $null) {
                $sccmProviderLocation = Get-WmiObject -query "select * from SMS_ProviderLocation where ProviderForLocalSite = true" -Namespace "root\sms" -computername $HostName -errorAction Stop
            } else {
                $sccmProviderLocation = Get-WmiObject -query "select * from SMS_ProviderLocation where ProviderForLocalSite = true" -Namespace "root\sms" -computername $HostName -credential $credential -errorAction Stop
            }
        } else {
            Write-Verbose "Getting provider location for site $siteCode on server $HostName"
            if ($credential -eq $null) {
                $sccmProviderLocation = Get-WmiObject -query "SELECT * FROM SMS_ProviderLocation where SiteCode = '$siteCode'" -Namespace "root\sms" -computername $HostName -errorAction Stop
            } else {
                $sccmProviderLocation = Get-WmiObject -query "SELECT * FROM SMS_ProviderLocation where SiteCode = '$siteCode'" -Namespace "root\sms" -computername $HostName -credential $credential -errorAction Stop
            }
        }
 
        # Split up the namespace path
        $parts = $sccmProviderLocation.NamespacePath -split "\\", 4
        Write-Verbose "Provider is located on $($sccmProviderLocation.Machine) in namespace $($parts[3])"
 
        # Create a new object with information
        $retObj = New-Object -TypeName System.Object
        $retObj | add-Member -memberType NoteProperty -name Machine -Value $HostName
        $retObj | add-Member -memberType NoteProperty -name Namespace -Value $parts[3]
        $retObj | add-Member -memberType NoteProperty -name SccmProvider -Value $sccmProviderLocation
 
        return $retObj
    }
}
 
Function Get-SCCMObject {
    #  Generic query tool
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server",ValueFromPipelineByPropertyName=$true)][Alias("Server","SmsServer")][System.Object] $SccmServer,
        [Parameter(Mandatory=$true, HelpMessage="SCCM Class to query",ValueFromPipeline=$true)][Alias("Table","View")][String] $class,
        [Parameter(Mandatory=$false,HelpMessage="Optional Filter on query")][String] $Filter = $null
    )
 
    PROCESS {
        if ($Filter -eq $null -or $Filter -eq "")
        {
            Write-Verbose "WMI Query: SELECT * FROM $class"
            $retObj = get-wmiobject -class $class -computername $SccmServer.Machine -namespace $SccmServer.Namespace
        }
        else
        {
            Write-Verbose "WMI Query: SELECT * FROM $class WHERE $Filter"
            $retObj = get-wmiobject -query "SELECT * FROM $class WHERE $Filter" -computername $SccmServer.Machine -namespace $SccmServer.Namespace
        }
 
        return $retObj
    }
}

#endregion

# --------------------------------------------------------------------------
Function Get-SCCMSite {
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server",ValueFromPipeline=$true)][Alias("Server","SmsServer")][System.Object] $SccmServer,
        [Parameter(Mandatory=$false, HelpMessage="Optional Filter on query")][String] $Filter = $null
    )
 
    PROCESS {
        return Get-SCCMObject -sccmServer $SccmServer -class "SMS_Site" -Filter $Filter
    }
}

Function Get-SCCMVirtualApp {
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server",ValueFromPipeline=$true)][Alias("Server","SmsServer")][System.Object] $SccmServer,
        [Parameter(Mandatory=$false, HelpMessage="Optional Filter on query")][String] $Filter = $null
    )
 
    PROCESS {
        return Get-SCCMObject -sccmServer $SccmServer -class "SMS_VirtualApp" -Filter $Filter
    }
}

Function Get-SCCMComputer {
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server")][Alias("Server","SmsServer")][System.Object] $SccmServer,
        [Parameter(Mandatory=$false, HelpMessage="Filter on SCCM Resource ID",ValueFromPipelineByPropertyName=$true)][int32] $ResourceID = $false,
        [Parameter(Mandatory=$false, HelpMessage="Filter on Netbiosname on computer",ValueFromPipeline=$true)][String] $NetbiosName = "%",
        [Parameter(Mandatory=$false, HelpMessage="Filter on Domain name",ValueFromPipelineByPropertyName=$true)][Alias("Domain", "Workgroup")][String] $ResourceDomainOrWorkgroup = "%",
        [Parameter(Mandatory=$false, HelpMessage="Filter on SmbiosGuid (UUID)")][String] $SmBiosGuid = "%"
    )
 
    PROCESS {
        if ($ResourceID -eq $false -and $NetbiosName -eq "%" -and $ResourceDomainOrWorkgroup -eq "%" -and $SmBiosGuid -eq "%") {
            throw "Need at least one filter..."
        }
 
        if ($ResourceID -eq $false) {
            return Get-SCCMObject -sccmServer $SccmServer -class "SMS_R_System" -Filter "NetbiosName LIKE '$NetbiosName' AND ResourceDomainOrWorkgroup LIKE '$ResourceDomainOrWorkgroup' AND SmBiosGuid LIKE '$SmBiosGuid'"
        } else {
            return Get-SCCMObject -sccmServer $SccmServer -class "SMS_R_System" -Filter "ResourceID = $ResourceID"
        }
    }
}
 
Function Get-SCCMUser {
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server")][Alias("Server","SmsServer")][System.Object] $SccmServer,
        [Parameter(Mandatory=$false, HelpMessage="Filter on SCCM Resource ID",ValueFromPipelineByPropertyName=$true)][int32] $ResourceID = $false,
        [Parameter(Mandatory=$false, HelpMessage="Filter on unique username in form DOMAIN\UserName",ValueFromPipelineByPropertyName=$true)][String] $UniqueUserName = "%",
        [Parameter(Mandatory=$false, HelpMessage="Filter on Domain name",ValueFromPipelineByPropertyName=$true)][Alias("Domain")][String] $WindowsNTDomain = "%",
        [Parameter(Mandatory=$false, HelpMessage="Filter on UserName",ValueFromPipeline=$true)][String] $UserName = "%"
    )
 
    PROCESS {
        if ($ResourceID -eq $false -and $UniqueUserName -eq "%" -and $WindowsNTDomain -eq "%" -and $UserName -eq "%") {
            throw "Need at least one filter..."
        }
 
        if ($ResourceID -eq $false) {
            return Get-SCCMObject -sccmServer $SccmServer -class "SMS_R_User" -Filter "UniqueUserName LIKE '$UniqueUserName' AND WindowsNTDomain LIKE '$WindowsNTDomain' AND UserName LIKE '$UserName'"
        } else {
            return Get-SCCMObject -sccmServer $SccmServer -class "SMS_R_User" -Filter "ResourceID = $ResourceID"
        }
    }
}
 
Function Get-SCCMCollectionMembers {
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server")][Alias("Server","SmsServer")][System.Object] $SccmServer,
        [Parameter(Mandatory=$false, HelpMessage="CollectionID", ValueFromPipeline=$true)][String] $CollectionID
    )
 
    PROCESS {
        return Get-SCCMObject -sccmServer $SccmServer -class "SMS_CollectionMember_a" -Filter "CollectionID = '$CollectionID'"
    }
}
 
Function Get-SCCMSubCollections {
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server")][Alias("Server","SmsServer")][System.Object] $SccmServer,
        [Parameter(Mandatory=$true, HelpMessage="CollectionID",ValueFromPipeline=$true)][Alias("parentCollectionID")][String] $CollectionID
    )
 
    PROCESS {
        return Get-SCCMObject -sccmServer $SccmServer -class "SMS_CollectToSubCollect" -Filter "parentCollectionID = '$CollectionID'"
    }
}
 
Function Get-SCCMParentCollection {
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server")][Alias("Server","SmsServer")][System.Object] $SccmServer,
        [Parameter(Mandatory=$true, HelpMessage="CollectionID",ValueFromPipeline=$true)][Alias("subCollectionID")][String] $CollectionID
    )
 
    PROCESS {
        $parentCollection = Get-SCCMObject -sccmServer $SccmServer -class "SMS_CollectToSubCollect" -Filter "subCollectionID = '$CollectionID'"
 
        return Get-SCCMCollection -sccmServer $SccmServer -Filter "CollectionID = '$($parentCollection.parentCollectionID)'"
    }
}
 
Function Get-SCCMSiteDefinition {
    # Get all definitions for one SCCM site
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server",ValueFromPipeline=$true)][Alias("Server","SmsServer")][System.Object] $SccmServer
    )
 
    PROCESS {
        Write-Verbose "Refresh the site $($SccmServer.SccmProvider.SiteCode) control file"
        Invoke-WmiMethod -path SMS_SiteControlFile -name RefreshSCF -argumentList $($SccmServer.SccmProvider.SiteCode) -computername $SccmServer.Machine -namespace $SccmServer.Namespace
 
        Write-Verbose "Get the site definition object for this site"
        return get-wmiobject -query "SELECT * FROM SMS_SCI_SiteDefinition WHERE SiteCode = '$($SccmServer.SccmProvider.SiteCode)' AND FileType = 2" -computername $SccmServer.Machine -namespace $SccmServer.Namespace
    }
}
 
Function Get-SCCMSiteDefinitionProps {
    # Get definitionproperties for one SCCM site
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server",ValueFromPipeline=$true)][Alias("Server","SmsServer")][System.Object] $SccmServer
    )
 
    PROCESS {
        return Get-SCCMSiteDefinition -sccmServer $SccmServer | ForEach-Object { $_.Props }
    }
}
 
Function Get-SCCMIsR2 {
    # Return $true if the SCCM server is R2 capable
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server",ValueFromPipeline=$true)][Alias("Server","SmsServer")][System.Object] $SccmServer
    )
 
    PROCESS {
        $result = Get-SCCMSiteDefinitionProps -sccmServer $SccmServer | ? {$_.PropertyName -eq "IsR2CapableRTM"}
        if (-not $result) {
            return $false
        } elseif ($result.Value = 31) {
            return $true
        } else {
            return $false
        }
    }
}
 
Function Get-SCCMCollectionRules {
    # Get a set of all collectionrules
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server")][Alias("Server","SmsServer")][System.Object] $SccmServer,
        [Parameter(Mandatory=$false, HelpMessage="CollectionID", ValueFromPipeline=$true)][String] $CollectionID
    )
 
    PROCESS {
        Write-Verbose "Collecting rules for $CollectionID"
        $col = [wmi]"$($SccmServer.SccmProvider.NamespacePath):SMS_Collection.CollectionID='$($CollectionID)'"
 
        return $col.CollectionRules
    }
}
 
Function Get-SCCMInboxes {
    # Give a count of files in the SCCM-inboxes
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server",ValueFromPipeline=$true)][Alias("Server","SmsServer")][System.Object] $SccmServer,
        [Parameter(Mandatory=$false, HelpMessage="Minimum number of files in directory")][int32] $minCount = 1
    )
 
    PROCESS {
        Write-Verbose "Reading \\$($SccmServer.Machine)\SMS_$($SccmServer.SccmProvider.SiteCode)\inboxes"
        return Get-ChildItem \\$($SccmServer.Machine)\SMS_$($SccmServer.SccmProvider.SiteCode)\inboxes -Recurse | Group-Object Directory | Where { $_.Count -gt $minCount } | Format-Table Count, Name -AutoSize
    }
}


#region Version 2.0

#------------------------------- Added functions in version 2.0---------------------------------------------



#----------------------------------- APP-V -------------------------------------------

#region App-V

Function New-SccmAppVPackage {
#Added by Stéphane van Gulick
	[CmdletBinding(SupportsShouldProcess=$true)]
	Param(
		[Parameter(Mandatory=$true, HelpMessage="Application Name")]$AppName, #ApplicationName
		[Parameter(Mandatory=$false, HelpMessage="Manufucturer of the application")]$Manufacturer, #The manufacturer of the application
		[Parameter(Mandatory=$true, HelpMessage="The Stagging folder where the app-v packages will be copied to for extra treatement.")]$smsShare,#App-V Stagging folder
		[Parameter(Mandatory=$false, HelpMessage="SCCM site where the application needs to be created on.")]$site, #SMS site name (trigram)
		[Parameter(Mandatory=$true, HelpMessage="Source folder of the application of the original App-V package.")]$ApplicationNameSourceFolder, #Source Folder of the appvPackage
		[Parameter(Mandatory=$true, HelpMessage="SCCM Server name where the application will be created on.")]$SCCMServer, #SMS server name where the package will be created
		[Parameter(Mandatory=$false, HelpMessage="Description of the application")]$Description,
		[Parameter(Mandatory=$false, HelpMessage="Language of the App-V Package.")]$Language #The language that the package will have.
		
	)
	
	Begin{

	Write-Verbose "Starting App-V integration process"
		
	}
Process {

	#Variables
			$ApplicationName = $Manufacturer + "_" + $AppName
			$ApplicationFolder = Join-Path -Path $smsShare -ChildPath $ApplicationName
	

	#AppVStaging

	#appVStaging folder
		try{
			$Destination = "$smsShare\$ApplicationName\"
			New-Item  "$smsShare\$ApplicationName\" -Type Directory -Force | Out-Null -ErrorAction Stop
			}
		catch{
			Write-Host "Error :" $_ "Could not create the AppVstagging folder $($Destination)"
		}
		
		write-verbose "App-V Destination Stagging folder will be : $($destination)"
		
	#AppShare = Location of the AppVSource files
		
		if (Test-Path $ApplicationNameSourceFolder)
			{
			Write-verbose "Copying content of $($ApplicationNameSourceFolder) to $($destination)"
			Copy-Item $ApplicationNameSourceFolder\* -Destination $Destination -Recurse -Force
			Write-verbose "Copy sucesfull of $($ApplicationNameSourceFolder) to $($destination)"
			}
		else{
		Write-Host "Couldn't copy $($ApplicationNameSourceFolder) to $($destination). Quiting" -ForegroundColor "red"
		exit
		}
		


	#XmlManifest
	Write-Verbose "----XML Manifest section----"
	#Getting the XML Manifest
		#Eventuall change *xml to manifest.xml
			try{
				Write-Verbose "Checking for the Manifest.xml file"
				$Manfst = Get-ChildItem "$smsShare\$ApplicationName\*manifest.xml" -Name
				}
			catch{
				Write-Host "Impossible to locate the Manifest.xml file in $smsShare\$ApplicationName\ . Quiting"
				exit
			}
			
		#Importing Xml manifest
			Write-verbose "Importing $($smsShare)\$($ApplicationName)\$($Manfst)"
			[xml]$Manifest = get-content "$smsShare\$ApplicationName\$Manfst"
			
		#Getting AppVPackage information
			$Name = $Manifest.Package.Name
			$GUID = $Manifest.Package.GUID
			$Version = $Manifest.Package.VersionGuid
			$Name = $Manifest.Package.Name
			
		#Generating the commandLine
			Write-Verbose "Generating the command line"
			$Commandline = "PkgGUID=" + "$GUID" + ":VersionGUID=" + "$Version"

		#Create the extended data variable.
			Write-Verbose "Creating extended data"
			$exData = [Text.Encoding]::UTF8.GetBytes($Version)
			$exDataSize = $exData.getupperbound(0) + 1




	
	#Getting OSD
	Write-Verbose "----OSD section----"
		Write-verbose "Working on the OSD settings. Searching for OSD file in $($applicationFolder)"
		$childs = Get-ChildItem $ApplicationFolder
		foreach ($file in $childs)
			{
				if ($file.extension -eq ".osd")
					{
					
						#Importing OSD data (XML format)
							Write-Verbose "OSD file found at $($file.fullname)"
							Write-verbose "importing $($file.fullname) and extracting App-V package information."
							[xml]$OSD = Get-Content $file.fullname
						
						#Getting OSD information from OSD file
							$PkgGUID = $OSD.Softpkg.GUID
							$PkgName = $OSD.Softpkg.Name
							$PkgVers = $OSD.Softpkg.Version
					
					}
			}
		

	#AppVPackage
	Write-Verbose "----App-V PAckage section----"
		#Creating a hastable with all the required arguments for the creation of the AppvPackage
			$argumentsPackage = @{Name = "$Name";
			Manufacturer = $Manufacturer;
			Description = $Description;
			ExtendedData = $exData;
			ExtendedDataSize = $exDataSize;
			Version = $PkgVers;
			Language = $language;
			PackageType = 7;
			PkgFlags = 104857600;
			PkgSourceFlag = 2;
			PkgSourcePath = "$smsShare\$ApplicationName\"
		}
		#Creating the Package through WMI
			
				try {
					Write-verbose "Creating the Appv Package"
					$SetPkg = Set-WmiInstance -Computername $SCCMServer.machine -class SMS_Package -arguments $argumentsPackage -namespace $SCCMServer.Namespace
					Write-verbose "$($setpkg) has been created successfully"
				}
				catch{
					Write-Host "$_ Errorduring the creating of the package App-V. Quiting" -ForegroundColor Red
					exit
				}
		#Getting application where Application Name = $ApplicationName (It will not work if error above)
			$Package = Get-WmiObject -Computername $SCCMServer.Machine -Namespace $SCCMServer.Namespace -Query "Select * from SMS_Package WHERE Name = '$Name'"

		#Getting PackageID
			$PackageID = $Package.PackageID


	#SFT+SPRJ
	Write-Verbose "----SFT and SPRJ section----"
	#Renaming SFT
		Write-verbose "Renaming sft to $($PackageID).sft"
		
		foreach ($file in (get-childitem $smsShare\$ApplicationName\))
			{
				if ($file.extension -eq "sft")
					{
					Rename-Item "$smsShare\$ApplicationName\*.sft" "$PackageID.sft"
					}
			}
		
	#Deleting .SPRJ
		Write-verbose "Deleting the sprj file"
		Remove-Item "$smsShare\$ApplicationName\*.sprj" -Force

	#ProgramCreation

	Write-Verbose "----Program Section----"

	#Creating arguments for Program creation
		$argumentsProgram = @{
		PackageID = $Package.PackageID;
		ProgramFlags = "135307273";
		ProgramName = "[Virtual application]";
		CommandLine = "$Commandline"
	}
	#Creating the program (WMI)
		try{
			Write-verbose "Creating the Program for the Appv Package"
			$SetPrg = Set-WmiInstance -Computername $SCCMServer.Machine -class SMS_Program -arguments $argumentsProgram -namespace $SCCMServer.Namespace
			Write-verbose "$SetPrg created sucessfully"
		}
		catch{
			Write-Host "$_ error while creating the AppV Program. Quiting" -ForegroundColor Red
			exit
		}


	#SFTRename
	$i = 0
		foreach ($f in $childs)
			{
				if($f.extension -eq ".sft")
					{
						Write-verbose "Renaming $f.fullname to $($pkguid.sft)"
						Rename-Item -Path $f.fullname -NewName "$PkgGUID.sft" 
					}
			
			
			}
				
		
	#Icons

	 Write-Verbose "----Icons section----"
		IF ($OSD.Softpkg.MGMT_Shortcutlist.Shortcut.count -like ""){
		
		    $RawIcon = $OSD.Softpkg.MGMT_Shortcutlist.Shortcut.Icon
			
			} 
		ELSE {
		
		    $RawIcon = $OSD.Softpkg.MGMT_Shortcutlist.Shortcut[0].Icon
		}
	 
		$RawIcon = $RawIcon -replace "/", "\"
		$Icon = $RawIcon -replace "%SFT_MIME_SOURCE%", $ApplicationFolder


	 #Reading icon properties 
	 	$Obj = New-Object -ComObject ADODB.Stream
		$Obj.Open()
		$Obj.Type = 1
		$Obj.LoadFromFile("$Icon")
		$IconData = $Obj.Read()
	 	$IconSize = $IconData.getupperbound(0) + 1

		
	#AppVInstanceCreation 
	Write-Verbose "----VirtualApp instance creation----"
		$argumentsApps = @{
		GUID = "$PkgGUID";
		IconSize = $IconSize;
		Icon = $IconData;
		PackageID = $Package.PackageID;
		Name = "$PkgName";
		Version = "$PkgVers"
		}
	 
		$VApp = Set-WmiInstance -Computername $SCCMServer.machine -class SMS_VirtualApp -arguments $argumentsApps -namespace $SCCMServer.namespace

	 
	Write-Verbose "End of App-V package creation process"
}
end{
	#Returning object
		return $Package
	}
	
}

#endregion

# - -------------------Software Updates- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -


#Region Software Updates

# - - - - - - - - - - Software update  - - - - - - - - - - - - - - -

Function Get-SCCMSoftwareUpdate {

<#
.SYNOPSIS
  Returns the software update
.DESCRIPTION
   Returns the existing software updates
.PARAMETER SccmServer
   Sccm Connection object created with Connect-SccmServer
.EXAMPLE
	$Connect-SccmServer = -SccmServer "MyServer01"
  	Get-SCCMSoftwareUpdate -SccmServer $connection
.NOTES
	Author: Stéphane van Gulick
#>

	[CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server",ValueFromPipeline=$true)][Alias("Server","SmsServer")][System.Object] $SccmServer,
		[Parameter(Mandatory=$false, HelpMessage="Search for a specific update based on the CI_UniqueID")][String]$CI_UniqueID = $null,
		[Parameter(Mandatory=$false, HelpMessage="Search for a specific update based on the CI_ID")][Int32]$CI_ID = $null,
		[Parameter(Mandatory=$false, HelpMessage="Search for a specific update based on the ArticleID")][String]$ArticleID = $null,
		[Parameter(Mandatory=$false, HelpMessage="Search for a specific update based on the BulletinID")][String]$BulletinID = $null,
		[Parameter(Mandatory=$false, HelpMessage="Optional Filter on query")][String] $Filter = $null
    )
	
	begin{
		Write-Verbose "Starting Software update process"
	}

	Process{
	
	
	switch ($PSBoundParameters.keys){
		("CI_UniqueID"){	$Result = Get-SCCMObject -sccmServer $SccmServer -class "SMS_SoftwareUpdate" -Filter "CI_UniqueID='$CI_UniqueID'"; break}
		("CI_ID"){$Result = Get-SCCMObject -sccmServer $SccmServer -class "SMS_SoftwareUpdate" -Filter "CI_ID='$CI_ID'" ; break}
		("ArticleID"){$Result = Get-SCCMObject -sccmServer $SccmServer -class "SMS_SoftwareUpdate" -Filter "ArticleID='$ArticleID'" ; break}
		("BulletinID"){$Result = Get-SCCMObject -sccmServer $SccmServer -class "SMS_SoftwareUpdate" -Filter "BulletinID='$BulletinID'" ; break}
		Default {$Result = Get-SCCMObject -sccmServer $SccmServer -class "SMS_SoftwareUpdate" -Filter $filter}
		}
		
	
	}
	end{
	Write-Verbose "Returning $($result)"
	return $Result
	
	}




}

# - - - - - - - - - - Software update Packages - - - - - - - - - - - - - - -

Function Get-SCCMSoftwareUpdatePackage {

<#
.SYNOPSIS
  Returns the software update packages.
.DESCRIPTION
   Queries for the software update packages.
.PARAMETER SccmServer
   Sccm Connection object created with Connect-SccmServer
.EXAMPLE
   Get-SccmSoftwareUpdatesGroup -SccmServer $connection -Filter "Name= 'Windows Server 2012 Software Updates'"
#>

	[CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server",ValueFromPipeline=$true)][Alias("Server","SmsServer")][System.Object] $SccmServer,
        [Parameter(Mandatory=$false, HelpMessage="Search for software update package based on name.")][String] $Name = $null,
		[Parameter(Mandatory=$false, HelpMessage="Search for software update package based on PackageID")][String] $PackageID = $null,
		[Parameter(Mandatory=$false, HelpMessage="Optional Filter on query")][String] $Filter = $null
    )
	
	begin{
	
	}
	Process{
	
		if ($name){
		
			$Result = Get-SCCMObject -sccmServer $SccmServer -class "SMS_SoftwareUpdatesPackage" -Filter "Name='$name'"
		
		}
		elseif($PackageID) {
			$Result = Get-SCCMObject -sccmServer $SccmServer -class "SMS_SoftwareUpdatesPackage" -Filter "PackageID='$PackageID'"
		}
		else{
			$Result = Get-SCCMObject -sccmServer $SccmServer -class "SMS_SoftwareUpdatesPackage" -Filter $Filter
		}
	}
	end{
	
	return $Result
	
	}




}

Function New-SCCMSoftwareUpdatePackage {	
<#
.SYNOPSIS
 Creates a software update package
.DESCRIPTION
 Creates a software update package. Need an UNC Path.
.PARAMETER SccmServer
   Sccm Connection object created with Connect-SccmServer
.EXAMPLE
	$Connect-SccmServer = -SccmServer "MyServer01"
  New-SCCMSoftwareUpdatePackage -name "Test" -description "test2" -PackageSourcePath "\\cbd05\repository\Software Packages\Software Updates\Test" -SccmServer $connection
.NOTES
	Author: Stéphane van Gulick
#>

	[CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server",ValueFromPipeline=$true)][Alias("Server","SmsServer")][System.Object] $SccmServer,
		[Parameter(Mandatory=$false, HelpMessage="Insert Site code")][String]$SiteCode,
		[Parameter(Mandatory=$true, HelpMessage="Input a valid UNC Path")][String]$PackageSourcePath,
		[Parameter(Mandatory=$true, HelpMessage="Input a valid name")][String]$Name,
		[Parameter(Mandatory=$false, HelpMessage="Input a valid description")][String]$Description,
        [Parameter(Mandatory=$false, HelpMessage="PackageSourceFlag")][String]$PackageSourceFlag

    )
	
	begin{
		write-verbose "Starting Software update Package creation"
	}
	Process{
	
		If (!($siteCode)){
		
			$siteCode = $sccmServer.SccmProvider.SiteCode
		}
	
	 	$WMI_SoftwareUpdatesPackage = [wmiclass]"\\$($sccmServer.machine)\$($sccmServer.Namespace):SMS_SoftwareUpdatesPackage"
		$NewInstance = $WMI_SoftwareUpdatesPackage.createInstance()
		$NewInstance.name = $Name
		$NewInstance.SourceSite = $siteCode
		$NewInstance.PkgSourcePath = $PackageSourcePath
        $NewInstance.PkgSourceFlag= $PackageSourceFlag
		$NewInstance.description = $Description
		$NewInstance.put() | Out-Null
		$NewInstance.get
		
		
		
	}
	end{
	
	return $NewInstance
	
	}
	
}

Function Remove-SCCMSoftwareUpdatePackage {

<#
.SYNOPSIS
  Deletes a Software update Package
.DESCRIPTION
   Deletes the software update Pacakge from SCCM (It doesn't delete the sources).
.PARAMETER SccmServer
   Sccm Connection object created with Connect-SccmServer
.EXAMPLE
	$Connect-SccmServer = -SccmServer "MyServer01"
  	Get-SCCMSoftwareUpdatelist -SccmServer $connection
.NOTES
	Author: Stéphane van Gulick
#>

	[CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server",ValueFromPipeline=$true)][Alias("Server","SmsServer")][System.Object] $SccmServer,
		[Parameter(Mandatory=$false, HelpMessage="Deletes a specific Software Update package based on the Name")][String]$Name = $null,
		[Parameter(Mandatory=$false, HelpMessage="Deletes a specific Software Update package based on the Package")][String]$PackageID = $null
	
    )
	
	begin{
		Write-Verbose "Starting Getting software update list process."
	}
	Process{
		
	
				If ($PackageID){$UpdatePackage = Get-SCCMSoftwareUpdatePackage -SccmServer $sccmServer -PackageID $PackageID}
				elseif ($name){$UpdatePackage = Get-SCCMSoftwareUpdatePackage -SccmServer $sccmServer -Name $name}
		
				if ($UpdatePackage){
					Write-Verbose "Deleting UpdateList : $($UpdatePackage.LocalizedDisplayName)."
					$UpdatePackage.delete()
				}
			
		}
	end{}
	
}	

Function Add-SCCMSoftwareUpdateToSoftwareUpdatePackage {

<#
.SYNOPSIS
 Creates a software update package
.DESCRIPTION
 Creates a software update package. Need an UNC Path.
.PARAMETER SccmServer
   Sccm Connection object created with Connect-SccmServer
.EXAMPLE
	$Connect-SccmServer = -SccmServer "MyServer01"
  
.NOTES
	Author: Stéphane van Gulick
#>

	[CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server",ValueFromPipeline=$true)][Alias("Server","SmsServer")][System.Object] $SccmServer,
		[Parameter(Mandatory=$false, HelpMessage="Insert a CI_ID of the Update (Do not use in conjunction with ArticleID, or CI_UniqueID")][String]$CI_ID,
		[Parameter(Mandatory=$false, HelpMessage="Insert a CI_UniqueID of the Update (Do not use in conjunction with ArticleID or CI_ID")][String]$CI_UniqueID,
		[Parameter(Mandatory=$false, HelpMessage="Insert the ArticleID of the Update (Do not use in conjunction with CI_ID or CI_UniqueID)")][String]$ArticleID,
		[Parameter(Mandatory=$true, HelpMessage="Input temporary UNC Path")][String]$TemporaryPath,
		[Parameter(Mandatory=$false, HelpMessage="Input a valid Package name")][String]$PackageName,
		[Parameter(Mandatory=$false, HelpMessage="Input a valid PackageID")][String]$UpdatePackageID
		#[Parameter(Mandatory=$false, HelpMessage="An array of CI_IDs of the software updates")][Array]$Updates		
    )
	
	begin{
		write-verbose "Starting to updates to Software update Package $($name)"
	}
	Process{
	        $AllContentIDs = @()
			$ContentID = @()
			$ContentPath = @()
			if ($PackageName){
				$UpdatePackage = Get-SCCMSoftwareUpdatePackage -SccmServer $sccmServer -Name $PackageName
				}
			elseif($UpdatePackageID){
			
				$updatePackage = Get-SCCMSoftwareUpdatePackage -SccmServer $sccmServer -PackageID $UpdatePackageID
			}
			
			if (!($updatePackage)){
				Write-Warning "The update package could not be found. Verify the package exists and try again."
				break
			}else{
				Write-Verbose "The update package $($updatePackage.name) with ID: $($updatePackage.PAckageID) has been found."
			}
			
			
			If ($ArticleID){
				$UpdateInfo = Get-SCCMSoftwareUpdate -SccmServer $SccmServer -ArticleID $ArticleID
				$CiUniqueID = $UpdateInfo.CI_UniqueID
				$CI_ID = $UpdateInfo.CI_ID
			}elseif ($CI_ID){
				$CiUniqueID = (Get-SCCMSoftwareUpdate -SccmServer $SccmServer -CI_ID $CI_ID).Ci_UniqueID
			}
			elseif($CI_UniqueID){
					$CI_ID = (Get-SCCMSoftwareUpdate -SccmServer $SccmServer -CI_UniqueID $CI_UniqueID).CI_ID
			}
			##To check
			$ContentIDs = Get-SCCMObject -sccmServer $SccmServer -class "SMS_CIToContent" -Filter "CI_ID='$CI_ID'"
            forEach($contentID in $ContentIDs){
                write-verbose "Working on $($contentID)"
                $ContentIDnumber = $ContentID.ContentID
                write-verbose "ContentIDnumber = $ContentIDnumber"
			    $ContentFile = Get-SCCMObject -sccmServer $SccmServer -class "SMS_CIContentFiles" -Filter "ContentID='$ContentIDnumber'"
			    $downloadUrl = $ContentFile.SourceUrl
			    $Filename = $ContentFile.filename
			
			    $DestinationFolder = Join-Path -path $TemporaryPath -ChildPath $CiUniqueID
			
			    if (!(Test-Path $DestinationFolder)){
				    mkdir $DestinationFolder | Out-Null
				    }
			
			    $destination = Join-Path -Path $DestinationFolder -ChildPath $Filename
			    Write-Verbose "Launching the download of CI_ID: $($CI_ID) from link: $($downloadUrl) to $($destination)"
			    $wc = New-Object System.Net.WebClient
			    #Import-Module bitsTransfer
			
			    try{
				    #start-bitsTransfer -Source $downloadUrl -Destination $destination
				    $wc.DownloadFile($downloadUrl, $destination)
				    }
			    catch{
				    $_.exception.message
			    }
			    $AllContentIDs += $ContentIDnumber
			    $ContentPath += "$DestinationFolder"
			}
			#$UpdatePackage = Get-SCCMSoftwareUpdatePackage -SccmServer $sccmServer -Name $Name
			
			$UpdatePackage = gwmi -Class SMS_SoftwareUpdatesPackage -computer $sccmServer.machine -namespace $sccmServer.namespace -Filter "Name = '$($updatePackage.name)'"
			$UpdatePackageLazy = [WMI]$UpdatePackage.__PATH
			#DK modified on 31.03.2014
			$UpdatePackageLazy.AddupdateContent($AllContentIDs,$ContentPath,$true) | out-null
			
			#Deleting temporary folder
			Remove-Item "$($DestinationFolder)" -Recurse
	}
	End{
	
		return $UpdatePackageLazy
	}

}

Function Remove-SCCMSoftwareUpdateFromSoftwareUpdatePackage {

<#
.SYNOPSIS
 Removes a software update package
.DESCRIPTION
 Creates a software update package. Need an UNC Path.
.PARAMETER SccmServer
   Sccm Connection object created with Connect-SccmServer
.EXAMPLE
	$Connect-SccmServer = -SccmServer "MyServer01"
  
.NOTES
	Author: Stéphane van Gulick
#>

	[CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server",ValueFromPipeline=$true)][Alias("Server","SmsServer")][System.Object] $SccmServer,
		[Parameter(Mandatory=$false, HelpMessage="Insert a CI_ID of the Update (Do not use in conjunction with ArticleID, or CI_UniqueID")][String]$CI_ID,
		[Parameter(Mandatory=$false, HelpMessage="Insert a CI_UniqueID of the Update (Do not use in conjunction with ArticleID or CI_ID")][String]$CI_UniqueID,
		[Parameter(Mandatory=$false, HelpMessage="Insert the ArticleID of the Update (Do not use in conjunction with CI_ID or CI_UniqueID)")][String]$ArticleID,
		[Parameter(Mandatory=$false, HelpMessage="Input a valid Package name")][String]$PackageName,
		[Parameter(Mandatory=$false, HelpMessage="Input a valid PackageID")][String]$UpdatePackageID
		#[Parameter(Mandatory=$false, HelpMessage="An array of CI_IDs of the software updates")][Array]$Updates		
    )
	
	begin{
		write-verbose "Starting to remove updates from Software update Package $($name)"
	}
	Process{
	
			$ContentID = @()
			$ContentPath = @()
			if ($PackageName){
				$UpdatePackage = Get-SCCMSoftwareUpdatePackage -SccmServer $sccmServer -Name $PackageName
				}
			elseif($UpdatePackageID){
			
				$updatePackage = Get-SCCMSoftwareUpdatePackage -SccmServer $sccmServer -PackageID $UpdatePackageID
			}
			
			if (!($updatePackage)){
				Write-Warning "The update package could not be found. Verify the package exists and try again."
				break
			}else{
				Write-Verbose "The update package $($updatePackage.name) with ID: $($updatePackage.PAckageID) has been found."
			}
			
			
			If ($ArticleID){
				$UpdateInfo = Get-SCCMSoftwareUpdate -SccmServer $SccmServer -ArticleID $ArticleID
				$CiUniqueID = $UpdateInfo.CI_UniqueID
				$CI_ID = $UpdateInfo.CI_ID
			}elseif ($CI_ID){
				$CiUniqueID = (Get-SCCMSoftwareUpdate -SccmServer $SccmServer -CI_ID $CI_ID).Ci_UniqueID
			}
			elseif($CI_UniqueID){
					$CI_ID = (Get-SCCMSoftwareUpdate -SccmServer $SccmServer -CI_UniqueID $CI_UniqueID).CI_ID
			}
			
			$ContentID = (Get-SCCMObject -sccmServer $SccmServer -class "SMS_CIToContent" -Filter "CI_ID='$CI_ID'").ContentID

			#$UpdatePackage = Get-SCCMSoftwareUpdatePackage -SccmServer $sccmServer -Name $Name
			#$UpdatePackage
			$UpdatePackage = gwmi -Class SMS_SoftwareUpdatesPackage -computer $sccmServer.machine -namespace $sccmServer.namespace -Filter "Name = '$($updatePackage.name)'"
			$UpdatePackageLazy = [WMI]$UpdatePackage.__PATH
			
            #Removing update from softwareupdate package
            #http://msdn.microsoft.com/en-us/library/cc144265.aspx
			    $UpdatePackageLazy.RemoveContent($ContentID,$false) | out-null
			
	}
	End{
	
		return $UpdatePackageLazy
	}

}

Function Get-SCCMSoftwareUpdatesPackageSourcePath {

<#
.SYNOPSIS
  NOT WORKING YET !!!
.DESCRIPTION
   Queries for the software update packages
.PARAMETER SccmServer
   Sccm Connection object created with Connect-SccmServer
.EXAMPLE
   	Get-SccmSoftwareUpdatesGroup -SccmServer $connection -Filter "Name= 'Windows Server 2012 Software Updates'"
.NOTES
	Author: Stéphane van Gulick
#>

	[CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server",ValueFromPipeline=$true)][Alias("Server","SmsServer")][System.Object] $SccmServer,
        [Parameter(Mandatory=$false, HelpMessage="Optional Filter on query")][String] $Filter = $null
    )
	
	begin{
	
	}
	Process{}
	end{
	
	return Get-SCCMObject -sccmServer $SccmServer -class "SMS_SoftwareUpdatesPackage" -Filter $Filter
	
	}




}

 
# - - - - - - - - - - Software update lists - - - - - - - - - - - - - - -

Function Get-SCCMSoftwareUpdateList {

<#
.SYNOPSIS
  Returns the software update lists
.DESCRIPTION
   Returns the existing software updates lists in SCCM
.PARAMETER SccmServer
   Sccm Connection object created with Connect-SccmServer
.PARAMETER Full
	Returns all the properties of the software update list.

.EXAMPLE
	$Connect-SccmServer = -SccmServer "MyServer01"
  	Get-SCCMSoftwareUpdatelist -SccmServer $connection
.NOTES
	Author: Stéphane van Gulick
#>

	[CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server",ValueFromPipeline=$true)][Alias("Server","SmsServer")][System.Object] $SccmServer,
        [Parameter(Mandatory=$false, HelpMessage="Optional Filter on query")][String] $Filter = $null,
		[Parameter(Mandatory=$false, HelpMessage="Search for a specific Software Update List based on the Name")][String]$Name = $null,
		[Parameter(Mandatory=$false, HelpMessage="Search for a specific Software Update List based on the CI_ID")][Int32]$CI_ID = $null,
		[Parameter(Mandatory=$false, HelpMessage="Will get all the properties (impacts performance)")][switch]$Full #Only use if really needed.
    )
	
	begin{
		Write-Verbose "Starting Getting software update list process."
	}

	Process{
	
	
			if($Name){
						$Result = Get-SCCMObject -sccmServer $SccmServer -class "SMS_AuthorizationList" -Filter "LocalizedDisplayName='$Name'"
							if ($Full){
									Write-verbose "Full Activated. Returning lazy properties. This might Impact performance !"
									[WMI]$Result = $Result.__Path
									
									}
								else{
									
								}
							}
			elseif($CI_ID){
							$Result = Get-SCCMObject -sccmServer $SccmServer -class "SMS_AuthorizationList" -Filter "CI_ID='$CI_ID'"
							if ($Full){
										Write-verbose "Full Activated. Returning lazy properties. This might Impact performance !"
										[WMI]$Result = $Result.__Path
										
									}
									else{
										
									}
							}
			else {
				Write-Verbose "No parameters."
				
						if ($Full){
									Write-verbose "Full Activated. Returning all the properties. This might Impact performance !"
									$Result = Get-SCCMObject -sccmServer $SccmServer -class "SMS_AuthorizationList" -Filter $filter
									#Lazy properties needs to be fetch individually...
										If ($Result.count -ge 2){
											$Temp = @()
											foreach ($res in $Result){
												$Temp += [WMI]$res.__Path
											}
											$result = $Temp
										}
										else{
											[WMI]$Result = $Result.__Path
											}
									
									}
						else{
							$Result = Get-SCCMObject -sccmServer $SccmServer -class "SMS_AuthorizationList" -Filter $filter
							
						}
				
				}#Endelse

		
	
	}
	end {
	Write-Verbose "Returning $($result)"
	
	return $result
	}

}

Function Update-SCCMSoftwareUpdateList {

<#
.SYNOPSIS
   Updates an already existing software update lists
.DESCRIPTION
   Updates an already existing software update lists based on the CI_ID of the software update list.
.PARAMETER SccmServer
   Sccm Connection object created with Connect-SccmServer.
.PARAMETER Name
	Name for the  Software update list.
.PARAMETER Description
	Description for the  Software update list.
.PARAMETER Updates
	An array of CI_ID updates that need to be added to the software update list.
.EXAMPLE
	$Connect-SccmServer = -SccmServer "MyServer01"
  	Update-SCCMSoftwareUpdateList -SccmServer $connection -CI_ID 151 -Name "Updated update list" -Description "New Update list discription" -updates 114
.NOTES
	Author: Stéphane van Gulick
#>

	[CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server",ValueFromPipeline=$true)][Alias("Server","SmsServer")][System.Object] $SccmServer,
        [Parameter(Mandatory=$true, HelpMessage="Input a valid name")][String]$Name,
		[Parameter(Mandatory=$true, HelpMessage="Software update list CI_ID")][String]$CI_ID,
		[Parameter(Mandatory=$false, HelpMessage="Input a valid description")][String]$Description,
		[Parameter(Mandatory=$false, HelpMessage="Collection of Update CI_IDs")][Array]$Updates
		)

	begin{}
	Process{
	
		if ($CI_ID){
			$UpdateList = Get-SCCMSoftwareUpdateList -SccmServer $sccmServer -CI_ID $CI_ID -Full
		}
		else{
			Write-Verbose "Neither a name or a CI_ID has been given to identify the correct Software update list. Returning null."
		}
	
			$WMI_LocalizedProperties = [wmiclass]"\\$($connection.machine)\$($connection.Namespace):SMS_CI_LocalizedProperties"
			$WMI_LocalizedProperties_Instance=$WMI_LocalizedProperties.createInstance()
			$WMI_LocalizedProperties_Instance.Displayname = $Name
			$WMI_LocalizedProperties_Instance.Description = $Description

			$UpdateList.localizedinformation = $WMI_LocalizedProperties_Instance
			$UpdateList.updates += $updates
			$UpdateList.put()
	}
	End{}

}

Function Add-SCCMSoftWareUpdateToSoftWareUpdateList {

<#
.SYNOPSIS
  !!!THIS FUNCTION IS NOT FINISHED YET!!!
.DESCRIPTION
   Returns the existing software updates lists in SCCM
.PARAMETER SccmServer
   Sccm Connection object created with Connect-SccmServer
.EXAMPLE
	$Connect-SccmServer = -SccmServer "MyServer01"
  	Get-SCCMSoftwareUpdatelist -SccmServer $connection
.NOTES
	Author: Stéphane van Gulick
#>

	[CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server",ValueFromPipeline=$true)][Alias("Server","SmsServer")][System.Object] $SccmServer,
        [Parameter(Mandatory=$false, HelpMessage="Optional Filter on query")][String] $Filter = $null,
		[Parameter(Mandatory=$true, HelpMessage="Search for a specific Software Update List based on the Name")][String]$Name = $null,
		[Parameter(Mandatory=$true, HelpMessage="Adds a software update based on the CI_ID")][Array]$CI_ID = $null
    )
	
	begin{
		Write-Verbose "Starting to ad software update to "
	}
	Process{
		#Call with Full switch. This can impact performances.
		$SoftwareUpdateList = Get-SCCMSoftwareUpdateList -Name $name -SccmServer $SccmServer -Full
		
		
	}




}

Function New-SCCMSoftwareUpdateList {
<#
.SYNOPSIS
   Creates a new software update lists
.DESCRIPTION
   Creates a new Software update list from scratch.
.PARAMETER SccmServer
   Sccm Connection object created with Connect-SccmServer.
.PARAMETER Name
	Name for the new Software update list.
.PARAMETER Description
	Description for the new Software update list.
.PARAMETER Updates
	An array of CI_ID updates.
.EXAMPLE
	$Connect-SccmServer = -SccmServer "MyServer01"
  	Get-SCCMSoftwareUpdatelist -SccmServer $connection
.NOTES
	Author: Stéphane van Gulick
#>

	[CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server",ValueFromPipeline=$true)][Alias("Server","SmsServer,hostname")][System.Object] $SccmServer,
        [Parameter(Mandatory=$true, HelpMessage="Input a valid name")][String]$Name,
		[Parameter(Mandatory=$false, HelpMessage="Input a valid description")][String]$Description,
		[Parameter(Mandatory=$false, HelpMessage="Collection of Update CI_IDs")][Array]$Updates
		)
		
		$WMI_SoftwareUpdatesList = [wmiclass]"\\$($sccmServer.machine)\$($sccmServer.Namespace):SMS_AuthorizationList"
		$SoftwareUpdatesList_Instance = $WMI_SoftwareUpdatesList.createInstance()
		#Creating Information Object
			$WMI_LocalizedProperties = [wmiclass]"\\$($SccmServer.machine)\$($SccmServer.Namespace):SMS_CI_LocalizedProperties"
			$WMI_LocalizedProperties_Instance=$WMI_LocalizedProperties.createInstance()
			$WMI_LocalizedProperties_Instance.Displayname = $Name
			$WMI_LocalizedProperties_Instance.Description = $Description

		$SoftwareUpdatesList_Instance.localizedinformation = $WMI_LocalizedProperties_Instance
		
		If ($updates){
			#An array of updates CI_IDs is needed.
			$SoftwareUpdatesList_Instance.updates = $updates
		}
		
		$SoftwareUpdatesList_Instance.put()
		
		

}

Function Remove-SCCMSoftwareUpdateList {

	<#
.SYNOPSIS
  Deletes a Software update list
.DESCRIPTION
   Deletes the software update list from SCCM
.PARAMETER SccmServer
   Sccm Connection object created with Connect-SccmServer
.EXAMPLE
	$Connect-SccmServer = -SccmServer "MyServer01"
  	Get-SCCMSoftwareUpdatelist -SccmServer $connection
.NOTES
	Author: Stéphane van Gulick
#>

	[CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server",ValueFromPipeline=$true)][Alias("Server","SmsServer")][System.Object] $SccmServer,
		[Parameter(Mandatory=$false, HelpMessage="Search for a specific Software Update List based on the Name")][String]$Name = $null,
		[Parameter(Mandatory=$false, HelpMessage="Search for a specific Software Update List based on the CI_ID")][Int32]$CI_ID = $null
	
    )
	
	begin{
		Write-Verbose "Starting Getting software update list process."
	}
	Process{
		
	
				If ($CI_ID){$UpdateList = Get-SCCMSoftwareUpdateList -SccmServer $sccmServer -CI_ID $CI_ID}
				elseif ($name){$UpdateList = Get-SCCMSoftwareUpdateList -SccmServer $sccmServer -Name $name}
		Write-Verbose "Update list : $($UpdateList)"
			if ($updateList){
				Write-Verbose "Deleting UpdateList : $($updatelist.LocalizedDisplayName) ."
				$updateList.delete()
			}
			
		}
	}

#---- Software update Deployments-------

Function Get-SCCMSoftwareUpdateDeployment {

<#
.SYNOPSIS
  Returns the software update lists
.DESCRIPTION
   Returns the existing software updates lists in SCCM
.PARAMETER SccmServer
   Sccm Connection object created with Connect-SccmServer
.EXAMPLE
	$Connect-SccmServer = -SccmServer "MyServer01"
  	Get-SCCMSoftwareUpdatelist -SccmServer $connection
.NOTES
	Author: Stéphane van Gulick
#>

	[CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server",ValueFromPipeline=$true)][Alias("Server","SmsServer")][System.Object] $SccmServer,
        [Parameter(Mandatory=$false, HelpMessage="Optional Filter on query")][String] $Filter = $null,
		[Parameter(Mandatory=$false, HelpMessage="Search for a specific Software Update deployment based on the Name")][String]$Name = $null,
		[Parameter(Mandatory=$false, HelpMessage="Search for a specific Software Update deployment based on the AssignmentID")][String]$DeploymentID = $null,
		[Parameter(Mandatory=$false, HelpMessage="Will get all the lazy properties (impacts performance !)")][switch]$Full #Only use if really needed.
    )
	
	begin{
		Write-Verbose "Starting Getting software update list process."
	}

	Process{
	
	#SMS_UpdatesAssignment has lazy properties !
	
	switch ($PSBoundParameters.values){
			($Name){$Result = Get-SCCMObject -sccmServer $SccmServer -class "SMS_UpdatesAssignment" -Filter "AssignmentName='$Name'"
						if ($Full){
								Write-verbose "Full Activated. Returning lazy properties. This might Impact performance !"
								[WMI]$Result = $Result.__Path
								break
								}
							else{
								Break
							}
					}
			($DeploymentID){
							$Result = Get-SCCMObject -sccmServer $SccmServer -class "SMS_UpdatesAssignment" -Filter "AssignmentID='$DeploymentID'"
								if ($Full){
										Write-verbose "Full Activated. Returning lazy properties. This might Impact performance !"
										[WMI]$Result = $Result.__Path
										break
										}
									else{
										Break
									}
						}
			default {$Result = Get-SCCMObject -sccmServer $SccmServer -class "SMS_UpdatesAssignment" -Filter $Filter}					
			}#End of switch
	}#End of process block
	End{
		Return $Result
	}

}

Function New-SCCMSoftwareUpdateDeployment {

		<#
.SYNOPSIS
  
.DESCRIPTION
   Deletes the software update list from SCCM
.PARAMETER SccmServer
   Sccm Connection object created with Connect-SccmServer
.EXAMPLE
	$Connect-SccmServer = -SccmServer "MyServer01"
  	Get-SCCMSoftwareUpdatelist -SccmServer $connection
.NOTES
	Author: Stéphane van Gulick
#>

	[CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server",ValueFromPipeline=$true)][Alias("Server","SmsServer")][System.Object] $SccmServer,
		[Parameter(Mandatory=$True, HelpMessage="Name for the Software Update deployment")][String]$Name,
		[Parameter(Mandatory=$false, HelpMessage="Name for the Software Update deployment description")][String]$Description,
		[Parameter(Mandatory=$True, HelpMessage="Collection where to deploy the Software Updates")][String]$CollectionID,
		[Parameter(Mandatory=$true, HelpMessage="Array of CI_IDs that need to be deployed.")][Array]$Updates,
		[Parameter(Mandatory=$true, HelpMessage="YYYYMMDDhhmm")][string]$StartTime,
		[Parameter(Mandatory=$true, HelpMessage="YYYYMMDDhhmm")][string]$EnforcementDeadline,
		[Parameter(Mandatory=$false, HelpMessage="Suppress reboots.")]$SuppressReboot,
		[Parameter(Mandatory=$true, HelpMessage="Switch to apply to subTargets or not.")][bool]$ApplyToSubTargets, #Bool
		[Parameter(Mandatory=$true, HelpMessage="Default is to apply")][int]$AssignmentAction,
		[Parameter(Mandatory=$true, HelpMessage="Log compliance to Windows event. ")][bool]$LogComplianceToWinEvent, #bool
		[Parameter(Mandatory=$true, HelpMessage="Notify user of new updates availability.")][bool]$NotifyUser, #Bool
		[Parameter(Mandatory=$false, HelpMessage="Activate SCOM alerts on failure.")][bool]$ActivateScomAlertsOnFailure,#bool
		[Parameter(Mandatory=$false, HelpMessage="Deployment is read only. Default is False.")][bool]$ReadOnly, #bool
		[Parameter(Mandatory=$false, HelpMessage="Send detailed compliance status. ")][bool]$SendDetailedNonComplianceStatus,
		[Parameter(Mandatory=$false, HelpMessage="Use UTC time.Default is local user time.")]$UTCtime,
		[Parameter(Mandatory=$false, HelpMessage="The LocaledID")]$LocaleID,
		[Parameter(Mandatory=$false, HelpMessage="the desired config type.1 = Required, 2= Not Allowed")]$DesiredConfigType,
		[Parameter(Mandatory=$false, HelpMessage="The DPLocality can be: 4 = DP_DOWNLOAD_FROM_LOCAL, 6 = DP_DOWNLOAD_FROM_REMOTE,17 = DP_NO_FALLBACK_UNPROTECTED ")]$DPLocality
		
		   
    )
	
	begin{
		Write-Verbose "Starting Getting software update list process."
	}
	Process{
	
		$WMI_SoftwareUpdatesAssignment = [wmiclass]"\\$($sccmServer.machine)\$($sccmServer.Namespace):SMS_UpdatesAssignment"
		Write-Verbose "creating new instance"
		$NewSoftwareUpdateAssignment = $WMI_SoftwareUpdatesAssignment.CreateInstance()
		$NewSoftwareUpdateAssignment.AssignmentName = $name
		$NewSoftwareUpdateAssignment.AssignmentDescription = $Description
		$NewSoftwareUpdateAssignment.TargetCollectionID = $CollectionID
		$NewSoftwareUpdateAssignment.AssignedCIs = $Updates
		#true to apply the configuration item assignment to a subcollection.
			$NewSoftwareUpdateAssignment.ApplyToSubTargets = $ApplyToSubTargets
			
		#Assignment Action: 1 = Detect , 2= Apply (2= default)
			switch ($AssignmentAction){
				("Detect") {$NewSoftwareUpdateAssignment.AssignmentAction = 1}
				("Apply") {$NewSoftwareUpdateAssignment.AssignmentAction = 2}
				default {$NewSoftwareUpdateAssignment.AssignmentAction = $AssignmentAction}
				}
    	#DesiredConfigType : 1 Required, 2= Not Allowed (1= default)
    		$NewSoftwareUpdateAssignment.DesiredConfigType = $DesiredConfigType
		
		#4 DP_DOWNLOAD_FROM_LOCAL, 6 DP_DOWNLOAD_FROM_REMOTE,17 DP_NO_FALLBACK_UNPROTECTED
			$NewSoftwareUpdateAssignment.DPLocality = $DPLocality
    	$NewSoftwareUpdateAssignment.LocaleID = $LocaleID
    	$NewSoftwareUpdateAssignment.LogComplianceToWinEvent = $LogComplianceToWinEvent
    	$NewSoftwareUpdateAssignment.NotifyUser = $NotifyUser
		$NewSoftwareUpdateAssignment.RaiseMomAlertsOnFailure = $ActivateScomAlertsOnFailure
		$NewSoftwareUpdateAssignment.ReadOnly = $ReadOnly
		$NewSoftwareUpdateAssignment.StartTime = $StartTime #+ "00.000000+***" #YYYYMMDDhhmm #String is needed
		$NewSoftwareUpdateAssignment.EnforcementDeadline = $EnforcementDeadline #+ "00.000000+***" #YYYYMMDDhhmm #String is needed
		$NewSoftwareUpdateAssignment.SuppressReboot = 0		
		$NewSoftwareUpdateAssignment.UseGMTTimes = $UTCtime
		$NewSoftwareUpdateAssignment.SendDetailedNonComplianceStatus = $SendDetailedNonComplianceStatus
		$NewSoftwareUpdateAssignment.put()
		
		
	}
	End{}

}

Function Remove-SCCMSoftwareUpdateDeployment {

<#
.SYNOPSIS
  Removes a Software update deployment.
.DESCRIPTION
   Deletes the software update deployment from the SCCM server permantly.
.PARAMETER SccmServer
   Sccm Connection object created with Connect-SccmServer
.PARAMETER DeploymentID
   Deletes a software update deployment according to the DeploymentID.
.PARAMETER Name
   Deletes a software update deployment according to his name.
.EXAMPLE
	$Connect-SccmServer = -SccmServer "MyServer01"
  	Get-SCCMSoftwareUpdatelist -SccmServer $connection
.NOTES
	Author: Stéphane van Gulick
#>

	[CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server",ValueFromPipeline=$true)][Alias("Server","SmsServer")][System.Object] $SccmServer,
        [Parameter(Mandatory=$false, HelpMessage="Optional Filter on query")][String] $Filter = $null,
		[Parameter(Mandatory=$false, HelpMessage="Search for a specific Software Update deployment based on the Name")][String]$Name = $null,
		[Parameter(Mandatory=$false, HelpMessage="Search for a specific Software Update deployment based on the AssignmentID")][String]$DeploymentID = $null,
		[Parameter(Mandatory=$false, HelpMessage="Will get all the lazy properties (impacts performance !)")][switch]$Full #Only use if really needed.
    )
	
	begin{
		Write-Verbose "Starting Getting software update list process."
	}

	Process{
		
		If ($Name){
			$SoftwareUpdateDeployment = Get-SCCMSoftwareUpdateDeployment -SccmServer $SccmServer -Name $Name
			}
		elseif($DeploymentID){
			$SoftwareUpdateDeployment = Get-SCCMSoftwareUpdateDeployment -SccmServer $SccmServer -deploymentID $DeploymentID
		}
		else{
			$SoftwareUpdateDeployment = Get-SCCMSoftwareUpdateDeployment -SccmServer $SccmServer -filter $filter
		}
		
	
	}
	end{
		Write-Verbose "Attempting to delete : $($SoftwareUpdateDeployment.AssignmentName)."
		$SoftwareUpdateDeployment.Delete()
	}


}

#EndRegion

# - - - - - - - - - - Task Sequence- - - - - - - - - - - - - - -

#region Task Sequence

# - - - - - - - - - - Task Sequences - - - - - - - - - - 

Function Get-SCCMTaskSequenceRelatedPackages {
<#
.SYNOPSIS
  Returnes the list of packages that a present in a Task sequence.
.DESCRIPTION
  Returnes the list of packages that a present in a Task sequence.
.PARAMETER SccmServer
   Sccm Connection object created with Connect-SccmServer
.EXAMPLE
	$Connection = Connect-SccmServer "MyServer01"
  	Get-SccmTaskSequenceRelatedPackages -SccmServer $connection
.NOTES
	Author: Stéphane van Gulick
	version: 1.0
	History:
.LINK
	www.PowerShellDistrict.com
#>

	 [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server",ValueFromPipeline=$true)][Alias("Server","SmsServer")][System.Object] $SccmServer,
		[Parameter(Mandatory=$false, HelpMessage="Task Sequence name")][String] $Name,
		[Parameter(Mandatory=$false, HelpMessage="Path to the folder")][String] $Description,
        [Parameter(Mandatory=$false, HelpMessage="Optional Filter on query")][String] $Sequence = $null
    )
 
    PROCESS {

		$References = (Get-SCCMTaskSequencePackage -SccmServer $SccmServer -Name $Name -Full).references
		$Packages = @()
			Foreach ($Reference in $References){
				$PackageName = $null
				$PackageName = (Get-SCCMPackage -SccmServer $SccmServer -PackageID $($Reference.package)).name
				if ($PackageName){
					$Properties = @{'Name'=$PackageName;'Program'=$($Reference.Program)}
					$Packages += New-Object -TypeName psobject -Property $Properties
				}
				
			}
			
		return $Packages
}
}

Function Import-SCCMTaskSequenceXML {
<#
.SYNOPSIS
  Imports a Task Sequence based on a exported XML file.
.DESCRIPTION
  Returnes the list of packages that a present in a Task sequence.
.PARAMETER SccmServer
   Sccm Connection object created with Connect-SccmServer
.EXAMPLE
	$Connection = Connect-SccmServer "MyServer01"
  	
.NOTES
	Author: Stéphane van Gulick
	version: 1.0
	History:
.LINK
	www.PowerShellDistrict.com
#>
	 [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server",ValueFromPipeline=$true)][Alias("Server","SmsServer")][System.Object] $SccmServer,
		[Parameter(Mandatory=$false, HelpMessage="Name of the new task sequence")][String] $Name,
		[Parameter(Mandatory=$false, HelpMessage="Description")][String] $Description,
        [Parameter(Mandatory=$false, HelpMessage="Path to the XML file")][String] $XMLFile = $null,
        [Parameter(Mandatory=$false, HelpMessage="BootImageID")][String] $BootImageID =$null,
        [Parameter(Mandatory=$false, HelpMessage="DependentProgram")][String] $DependentProgram

    )
 
    PROCESS {
		
	#Gathering XML content :
		$XMLFileContent = $XMLFile
	
	#Getting SMS_TaskSequencePackage class
		$TaskSequencePackageClass = [WmiClass]("\\$($SccmServer.machine)\$($SccmServer.namespace):SMS_TaskSequencePackage")
	
	#Importing XML
		$importedsequence = ($TaskSequencePackageClass.ImportSequence($XMLFileContent)).TaskSequence
	#Creating Instance
		$NewInstance = $TaskSequencePackageClass.createinstance()
		$NewInstance.Name = $Name
		$NewInstance.Description = $Description
        $NewInstance.BootImageID= $BootImageID
        $NewInstance.DependentProgram=$DependentProgram
    #Importing Task Sequence
		$TaskSequencePackageClass.SetSequence($NewInstance,$importedsequence) 
    

       
	
     return $importedsequence
	

	}
}

Function Export-SCCMTaskSequence {
<#
.SYNOPSIS
  Exports the SCCM Task sequence to an Xml file format.
.DESCRIPTION
  
.PARAMETER SccmServer
   Sccm Connection object created with Connect-SccmServer
	
.PARAMETER PackageID
   The task sequence package ID of the task sequence to export.
	
.PARAMETER Name
   The name of task sequence to export.
	
.PARAMETER Path
	The path where the XML file should be saved.
	
.EXAMPLE
	$Connection = Connect-SccmServer "MyServer01"
  	Export-SccmTaskSequence -SccmServer $connection -name "Windows 7 deployment x64" -Path "\\share\exports\Windows7deploymentx64.xml"
.NOTES
	Author: Stéphane van Gulick
	version: 1.0
	History:
.LINK
	www.PowerShellDistrict.com
#>
 [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server",ValueFromPipeline=$true)][Alias("Server","SmsServer")][System.Object] $SccmServer,
		[Parameter(Mandatory=$false, HelpMessage="Gets task sequence according to name.")][String] $Name = $null,
		[Parameter(Mandatory=$false, HelpMessage="Gets task sequence according to PAckageID.")][String] $PackageID = $null,
        [Parameter(Mandatory=$false, HelpMessage="File with XML extension.")][String] $Path = $null
    )
 
    PROCESS {
	
		If ($name){
			$TaskSequenceXML = (Get-SCCMTaskSequencePackage -SccmServer $sccmServer -Name $Name -Full).sequence
			}
		elseif($PackageID){
			$TaskSequenceXML = (Get-SCCMTaskSequencePackage -SccmServer $sccmServer -Name $Name -Full).sequence
		}
		
		if ($path){
			$TaskSequenceXML | Out-File $Path
			}
		else{
			Return $TaskSequenceXML
		}
		}
	end{
		
	}
		

}

Function Get-SCCMTaskSequencePackage {
<#
.SYNOPSIS
  Gets a SCCM Task sequence package.
.DESCRIPTION
  
.PARAMETER SccmServer
   Sccm Connection object created with Connect-SccmServer
	
.PARAMETER PackageID
	Get the TS package according to his Task sequence package ID.
	
.PARAMETER Name
   Get the TS package according to his Task sequence name.
	
.PARAMETER Path
	The path where the XML file should be saved.
	
.EXAMPLE
	$Connection = Connect-SccmServer "MyServer01"
  	Get-SCCMTaskSequencePackage -SccmServer $connection -name "Windows 7 deployment x64"
	
.NOTES
	Author: Stéphane van Gulick
	version: 1.0
	History:
.LINK
	www.PowerShellDistrict.com
#>
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server",ValueFromPipeline=$true)][Alias("Server","SmsServer")][System.Object] $SccmServer,
		[Parameter(Mandatory=$false, HelpMessage="Optional Filter on query")][String] $Name = $null,
		[Parameter(Mandatory=$false, HelpMessage="Optional Filter on query")][String] $PackageID = $null,
        [Parameter(Mandatory=$false, HelpMessage="Optional Filter on query")][String] $Filter = $null,
		[Parameter(Mandatory=$false, HelpMessage="Full")][Switch] $Full
    )
 
    PROCESS {
	
		If ($name){
			$res = Get-SCCMObject -sccmServer $SccmServer -class "SMS_TaskSequencePackage" -Filter "Name='$Name'"
		}elseif($PackageID){
			$res = Get-SCCMObject -sccmServer $SccmServer -class "SMS_TaskSequencePackage" -Filter "PackageID='$PackageID'"
		}else{
		
			$res = Get-SCCMObject -sccmServer $SccmServer -class "SMS_TaskSequencePackage" -Filter $Filter
		
		}
	
		if ($Full){
			
			$res.get()
		}
    }
	end{
		return $res
	}
}

Function Get-SCCMTaskSequence {
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server",ValueFromPipeline=$true)][Alias("Server","SmsServer")][System.Object] $SccmServer,
        [Parameter(Mandatory=$false, HelpMessage="Optional Filter on query")][String] $Filter = $null
    )
 
    PROCESS {
        return Get-SCCMObject -sccmServer $SccmServer -class "SMS_TaskSequence" -Filter $Filter
    }
}

#endregion

# - - - - - - - - - - Drivers- - - - - - - - - - - - - - -

#region Drivers

Function New-SCCMDriver {
	
<#
.SYNOPSIS
  Imports a new driver into SCCM
.DESCRIPTION
  Based on UNC path and InfFile, the driver will be imported into SCCM.
.PARAMETER SccmServer
   Sccm Connection object created with Connect-SccmServer
.EXAMPLE
	$Connection = Connect-SccmServer "MyServer01"
  	
.NOTES
	Author: Stéphane van Gulick
	version: 1.0
	History:
.LINK
	www.PowerShellDistrict.com
#>
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server")][Alias("Server","SmsServer")][System.Object] $SccmServer,
        [Parameter(Mandatory=$true)] [String]$Path,
        [Parameter(Mandatory=$true)] [String]$InfFile
          
        
    )
    PROCESS {

            $DriverClass = [WmiClass]("\\$($SccmServer.machine)\$($SccmServer.namespace):SMS_Driver")
            $ret = ($DriverClass.CreateFromINF($Path,$InfFile)).Driver
            $Driver = $DriverClass.CreateInstance()
            $Driver.ContentSourcePath=$ret.ContentSourcePath
            $Driver.SDMPackageXML=$ret.SDMPackageXML

            #Calling Method
            $Driver.isenabled = $true
            #Creating the Driver XML paths
                  $xml=[xml]$Driver.SDMPackageXML
                  
            #Creating localized properties
                  
                  $WMI_LocalizedProperties = [wmiclass]"\\$($SccmServer.machine)\$($SccmServer.Namespace):SMS_CI_LocalizedProperties"
                  #Creating Localized properties instance
                        $WMI_LocalizedProperties_Instance=$WMI_LocalizedProperties.createInstance()
                  #Setting information
                        $WMI_LocalizedProperties_Instance.Displayname = $xml.DesiredConfigurationDigest.Driver.Annotation.DisplayName.Text
                        $WMI_LocalizedProperties_Instance.Description = $xml.DesiredConfigurationDigest.Driver.Annotation.Description.text
                        $WMI_LocalizedProperties_Instance.informativeurl = "http:\\Test.html"
                        $WMI_LocalizedProperties_Instance.localeID = "1033"
                        #$WMI_LocalizedProperties_Instance
            #Setting Localized properties 
                  $Driver.LocalizedInformation = $WMI_LocalizedProperties_Instance
                  #$Driver.Driver.LocalizedInformation
            #Confirming changes by calling put
                  $Driver.put()
                  #$DriverClass.put() #| out-null
                  $DriverClass.get()
 
    }
}

Function Add-SCCMDriversToBootImage {
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server",ValueFromPipeline=$true)][Alias("Server","SmsServer")][System.Object] $SccmServer,
		[Parameter(Mandatory=$true, HelpMessage="Boot image packageid ")][String] $PackageID,
		[Parameter(Mandatory=$true, HelpMessage="Driver CI_UniqueID")][Array] $DriverCI_UniqueIDs
 
    )
 	Process{
		
			$BootImagePackage = Get-SCCMBootImagePackage -SccmServer $SccmServer -Filter ("PackageID='$PackageID'")
		    $BootImagePackage.get()
            $DriverDetailsArray=@() 
		  forEach($DriverCI_UniqueID in $DriverCI_UniqueIDs){
		    #Gathering Driver information
			    $Driver= Get-SCCMDriver -SccmServer $SccmServer -Driver_UniqueID $DriverCI_UniqueID  
			    $Driver.get()
		
		    #Creating Driver_Details instance
			    Write-Verbose "creating new instance"
			    $DriverDetails_Class = [wmiclass]"\\$($sccmServer.machine)\$($sccmServer.Namespace):SMS_Driver_Details"
			    $DriverDetails_Instance = $DriverDetails_Class.CreateInstance()
			    $DriverDetails_Instance.ID = $Driver.CI_ID
			    $DriverDetails_Instance.SourcePath = $Driver.ContentSourcePath
                $DriverDetailsArray+= $DriverDetails_Instance
		}	
			
			Write-Verbose "Adding Drivers"
			$BootImagePackage.ReferencedDrivers = [System.Management.ManagementBaseObject[]]$DriverDetailsarray

		    $BootImagePackage.put()
	
	}

 
 }

Function Add-SCCMDriverToDriverPackage {

   [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server",ValueFromPipeline=$true)][Alias("Server","SmsServer")][System.Object] $SccmServer,
		[Parameter(Mandatory=$false, HelpMessage="Gets Driver package by name")][String] $DriverPackageName,
		[Parameter(Mandatory=$true, HelpMessage="Get driver by CI_UniqueID")][String] $DriverCI_UniqueID,
		[Parameter(Mandatory=$false, HelpMessage="Refresh DP's")][Boolean]$refreshDPs = $false
    )
 	Process{
		
		$DriverPackage = Get-SCCMDriverPackage -SccmServer $sccmserver -Filter ("Name='$DriverPackageName'")
        $DriverPackage.get()
		$Driver = Get-SCCMDriver -SccmServer $Sccmserver -Driver_UniqueID $DriverCI_UniqueID		
		$ContentID = Get-contentID -sccmServer $SccmServer -CI_ID $Driver.CI_ID
		$driverPackage.AddDriverContent($ContentID, $Driver.ContentSourcePath, $refreshDPs)
	}
}

Function Get-SCCMDriver {
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server",ValueFromPipeline=$true)][Alias("Server","SmsServer")][System.Object] $SccmServer,
		[Parameter(Mandatory=$false, HelpMessage="Get package by name")][String] $Name,
		[Parameter(Mandatory=$false, HelpMessage="Get driver by CI_ID")][String] $CI_ID ,
		[Parameter(Mandatory=$false, HelpMessage="Get driver by CI_UniqueID")][String] $Driver_UniqueID,
		[Parameter(Mandatory=$false, HelpMessage="Returns all the lazy properties")][Switch] $Full,
        [Parameter(Mandatory=$false, HelpMessage="Optional Filter on query")][String] $Filter = $null
    )
 
    PROCESS {
	
		If ($Name){
			$res = Get-SCCMObject -sccmServer $SccmServer -class "SMS_Driver" -Filter "LocalizedDisplayName='$Name'"
		}elseif($CI_ID){
			$res = Get-SCCMObject -sccmServer $SccmServer -class "SMS_Driver" -Filter "CI_ID='$CI_ID'"
		}elseif($Driver_UniqueID){
            $DriverID=$Driver_UniqueID.Split("/")[1]
			$res = Get-SCCMObject -sccmServer $SccmServer -class "SMS_Driver" -Filter "CI_UniqueID LIKE '%$DriverID'"
			}
		else{
		
			 $res=Get-SCCMObject -sccmServer $SccmServer -class "SMS_Driver" -Filter $Filter
		     
		}	
		
		if ($Full)
			{$res.get()}
        return $res
	
        
    }
}
 
# - - - - - - - - - - DriverPackage- - - - - - - - - - 

Function Get-SCCMDriverPackage {
<#
.SYNOPSIS
  Returnes the list of driver packages.
.DESCRIPTION
 
.PARAMETER SccmServer
   Sccm Connection object created with Connect-SccmServer
.EXAMPLE
	$Connection = Connect-SccmServer "MyServer01"
  	Get-SccmDriverPackage -SccmServer $connection
.NOTES
	Author: Stéphane van Gulick
	version: 1.0
	History:
.LINK
	www.PowerShellDistrict.com
#>	

    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server",ValueFromPipeline=$true)][Alias("Server","SmsServer")][System.Object] $SccmServer,
		[Parameter(Mandatory=$false, HelpMessage="Get package by name")][String] $Name = $null,
		[Parameter(Mandatory=$false, HelpMessage="Get package by PackageID")][String] $PackageID = $null,
        [Parameter(Mandatory=$false, HelpMessage="Optional Filter on query")][String] $Filter = $null
    )
 
    PROCESS {
	
		If ($Name){
			$res = Get-SCCMObject -sccmServer $SccmServer -class "SMS_DriverPackage" -Filter "Name='$Name'"
		}elseif($PackageID){
			$res = Get-SCCMObject -sccmServer $SccmServer -class "SMS_DriverPackage" -Filter "PackageID='$PackageID'"
		}else{
		
			$res = Get-SCCMObject -sccmServer $SccmServer -class "SMS_DriverPackage" -Filter $Filter
		
		}	
	
        return $res
	
        
    }
}

Function New-SCCMDriverPackage {
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server")][Alias("Server","SmsServer")][System.Object] $SccmServer,
        [Parameter(Mandatory=$false)] [String]$AlternateContentProviders,
          [Parameter(Mandatory=$false)] [String]$Description,
          [Parameter(Mandatory=$false)] [String]$ForcedDisconnectDelay,
          [Parameter(Mandatory=$false)] [Boolean]$ForcedDisconnectEnabled,
          [Parameter(Mandatory=$false)] [String]$ForcedDisconnectNumRetries,
          [Parameter(Mandatory=$false)] [Boolean]$IgnoreAddressSchedule,
          [Parameter(Mandatory=$false)] [String]$Language,
          [Parameter(Mandatory=$false)] [String]$Manufacturer,
          [Parameter(Mandatory=$false)] [String]$MIFFilename,
          [Parameter(Mandatory=$false)] [String]$MIFName,
          [Parameter(Mandatory=$false)] [String]$MIFPublisher,
          [Parameter(Mandatory=$false)] [String]$MIFVersion,
          [Parameter(Mandatory=$false)] [String]$Name,
          [Parameter(Mandatory=$false)] [String]$PackageType,
          [Parameter(Mandatory=$false)] [String]$PkgFlags,
          [Parameter(Mandatory=$false)] [String]$PkgSourceFlag,
          [Parameter(Mandatory=$false)] [String]$PkgSourcePath,
          [Parameter(Mandatory=$false)] [String]$PreferredAddressType,
          [Parameter(Mandatory=$false)] [String]$Priority,
          [Parameter(Mandatory=$false)] [Boolean]$RefreshPkgSourceFlag,
          [Parameter(Mandatory=$false)] [String]$ShareName,
          [Parameter(Mandatory=$false)] [String]$ShareType,
          [Parameter(Mandatory=$false)] [String]$StoredPkgPath,
          [Parameter(Mandatory=$false)] [String]$StoredPkgVersion,
          [Parameter(Mandatory=$false)] [String]$Version
  

        
    )
    PROCESS {
        $strServer = $SccmServer.machine
        $strNamespace= $SccmServer.namespace
        $DriverClass = [WmiClass]("\\$strServer\" + "$strNameSpace" + ":SMS_DriverPackage")
        $driver=$DriverClass.CreateInstance()

        #Set properties of DriverPackage
          if($AlternateContentProviders -ne ""){$driver.AlternateContentProviders=$AlternateContentProviders}
          if($Description -ne ""){$driver.Description=$Description}
          if($ForcedDisconnectDelay -ne ""){$driver.ForcedDisconnectDelay=$ForcedDisconnectDelay}
          if($ForcedDisconnectEnabled -ne ""){$driver.ForcedDisconnectEnabled=$ForcedDisconnectEnabled}
          if($ForcedDisconnectNumRetries -ne ""){$driver.ForcedDisconnectNumRetries=$ForcedDisconnectNumRetries}
          if($IgnoreAddressSchedule -ne ""){$driver.IgnoreAddressSchedule=$IgnoreAddressSchedule}
          if($Language -ne ""){$driver.Language=$Language}
          if($Manufacturer -ne ""){$driver.Manufacturer=$Manufacturer}
          if($MIFFilename -ne ""){$driver.MIFFilename=$MIFFilename}
          if($MIFName -ne ""){$driver.MIFName=$MIFName}
          if($MIFPublisher -ne ""){$driver.MIFPublisher=$MIFPublisher}
          if($MIFVersion -ne ""){$driver.MIFVersion=$MIFVersion}
          if($Name -ne ""){$driver.Name=$Name}
          if($PackageType -ne ""){$driver.PackageType=$PackageType}
          if($PkgFlags -ne ""){$driver.PkgFlags=$PkgFlags}
          if($PkgSourceFlag -ne ""){$driver.PkgSourceFlag=$PkgSourceFlag}
          if($PkgSourcePath -ne ""){$driver.PkgSourcePath=$PkgSourcePath}
          if($PreferredAddressType -ne ""){$driver.PreferredAddressType=$PreferredAddressType}
          if($Priority -ne ""){$driver.Priority=$Priority}
          if($RefreshPkgSourceFlag -ne ""){$driver.RefreshPkgSourceFlag=$RefreshPkgSourceFlag}
          if($ShareName -ne ""){$driver.ShareName=$ShareName}
          if($ShareType -ne ""){$driver.ShareType=$ShareType}
          if($StoredPkgPath -ne ""){$driver.StoredPkgPath=$StoredPkgPath}
          if($StoredPkgVersion -ne ""){$driver.StoredPkgVersion=$StoredPkgVersion}
          if($Version -ne ""){$driver.Version=$Version}
        

        $driver.Put() |out-null
        $driver.get()
        return $driver
       
    }
}

Function Update-SCCMDriverPackage {
    [CmdletBinding()]
    PARAM (
          [Parameter(Mandatory=$true, HelpMessage="SCCM Server")][Alias("Server","SmsServer")][System.Object] $SccmServer,
          [Parameter(Mandatory=$true)] [String]$PackageID,
          [Parameter(Mandatory=$false)] [String]$AlternateContentProviders,
          [Parameter(Mandatory=$false)] [String]$Description,
          [Parameter(Mandatory=$false)] [String]$ForcedDisconnectDelay,
          [Parameter(Mandatory=$false)] [Boolean]$ForcedDisconnectEnabled,
          [Parameter(Mandatory=$false)] [String]$ForcedDisconnectNumRetries,
          [Parameter(Mandatory=$false)] [Boolean]$IgnoreAddressSchedule,
          [Parameter(Mandatory=$false)] [String]$Language,
          [Parameter(Mandatory=$false)] [String]$Manufacturer,
          [Parameter(Mandatory=$false)] [String]$MIFFilename,
          [Parameter(Mandatory=$false)] [String]$MIFName,
          [Parameter(Mandatory=$false)] [String]$MIFPublisher,
          [Parameter(Mandatory=$false)] [String]$MIFVersion,   
          [Parameter(Mandatory=$false)] [String]$PackageType,
          [Parameter(Mandatory=$false)] [String]$PkgFlags,
          [Parameter(Mandatory=$false)] [String]$PkgSourceFlag,
          [Parameter(Mandatory=$false)] [String]$PkgSourcePath,
          [Parameter(Mandatory=$false)] [String]$PreferredAddressType,
          [Parameter(Mandatory=$false)] [String]$Priority,
          [Parameter(Mandatory=$false)] [String]$RefreshPkgSourceFlag,
          [Parameter(Mandatory=$false)] [String]$ShareName,
          [Parameter(Mandatory=$false)] [String]$ShareType,
          [Parameter(Mandatory=$false)] [String]$StoredPkgPath,
          [Parameter(Mandatory=$false)] [String]$StoredPkgVersion,
          [Parameter(Mandatory=$false)] [String]$Version
  

        
    )
    PROCESS {
        $driver=Get-SCCMDriverPackage -SccmServer $SccmServer -Filter ("PackageID='$PackageID'")

        #Set properties of DriverPackage
          if($AlternateContentProviders -ne ""){$driver.AlternateContentProviders=$AlternateContentProviders}
          if($Description -ne ""){$driver.Description=$Description}
          if($ForcedDisconnectDelay -ne ""){$driver.ForcedDisconnectDelay=$ForcedDisconnectDelay}
          if($ForcedDisconnectEnabled -ne ""){$driver.ForcedDisconnectEnabled=$ForcedDisconnectEnabled}
          if($ForcedDisconnectNumRetries -ne ""){$driver.ForcedDisconnectNumRetries=$ForcedDisconnectNumRetries}
          if($IgnoreAddressSchedule -ne ""){$driver.IgnoreAddressSchedule=$IgnoreAddressSchedule}
          if($Language -ne ""){$driver.Language=$Language}
          if($Manufacturer -ne ""){$driver.Manufacturer=$Manufacturer}
          if($MIFFilename -ne ""){$driver.MIFFilename=$MIFFilename}
          if($MIFName -ne ""){$driver.MIFName=$MIFName}
          if($MIFPublisher -ne ""){$driver.MIFPublisher=$MIFPublisher}
          if($MIFVersion -ne ""){$driver.MIFVersion=$MIFVersion}
          
          if($PackageType -ne ""){$driver.PackageType=$PackageType}
          if($PkgFlags -ne ""){$driver.PkgFlags=$PkgFlags}
          if($PkgSourceFlag -ne ""){$driver.PkgSourceFlag=$PkgSourceFlag}
          if($PkgSourcePath -ne ""){$driver.PkgSourcePath=$PkgSourcePath}
          if($PreferredAddressType -ne ""){$driver.PreferredAddressType=$PreferredAddressType}
          if($Priority -ne ""){$driver.Priority=$Priority}
          if($RefreshPkgSourceFlag -ne ""){$driver.RefreshPkgSourceFlag=$RefreshPkgSourceFlag}
          if($ShareName -ne ""){$driver.ShareName=$ShareName}
          if($ShareType -ne ""){$driver.ShareType=$ShareType}
          if($StoredPkgPath -ne ""){$driver.StoredPkgPath=$StoredPkgPath}
          if($StoredPkgVersion -ne ""){$driver.StoredPkgVersion=$StoredPkgVersion}
          if($Version -ne ""){$driver.Version=$Version}
        

        $driver.Put() |out-null
        $driver.get()
        return $driver
       
    }
}

#endregion


# - - - - - - - - - - Image Package (Operating System)- - - - - - - - - - - - - - -

#region ImagePAckage
Function Get-SCCMImagePackage {
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server",ValueFromPipeline=$true)][Alias("Server","SmsServer")][System.Object] $SccmServer,
		[Parameter(Mandatory=$false, HelpMessage="Get package by name")][String] $Name = $null,
		[Parameter(Mandatory=$false, HelpMessage="Get package by PackageID")][String] $PackageID = $null,
        [Parameter(Mandatory=$false, HelpMessage="Optional Filter on query")][String] $Filter = $null
    )
 
    PROCESS {
	
		If ($name){
			$res = Get-SCCMObject -sccmServer $SccmServer -class "SMS_ImagePackage" -Filter "Name='$Name'"
		}elseif($PackageID){
			$res = Get-SCCMObject -sccmServer $SccmServer -class "SMS_ImagePackage" -Filter "PackageID='$PackageID'"
		}else{
		
			$res = Get-SCCMObject -sccmServer $SccmServer -class "SMS_ImagePackage" -Filter $Filter
		
		}	
	
        return $res
	
        
    }
}

Function New-SCCMImagePackage {
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server")][Alias("Server","SmsServer")][System.Object] $SccmServer,
        
        [Parameter(Mandatory=$true)] [String]$Name,
        [Parameter(Mandatory=$false)] [String]$Version,
        [Parameter(Mandatory=$false)] [String]$Language,
        [Parameter(Mandatory=$false)] [String]$Manufacturer,
        [Parameter(Mandatory=$false)] [String]$Description,
        [Parameter(Mandatory=$false)] [String]$PkgSourceFlag=2,
        [Parameter(Mandatory=$false)] [String]$PkgSourcePath,
        [Parameter(Mandatory=$false)] [String]$PackageType="4"
       
        
    )
    PROCESS {
        $strServer = $SccmServer.machine
        $strNamespace= $SccmServer.namespace
        $imgPackageClass = [WmiClass]("\\$strServer\" + "$strNameSpace" + ":SMS_ImagePackage")
        $imgPackage=$imgPackageClass.CreateInstance()
        
        #Set properties of image package
        if($Name -ne ""){$imgPackage.Name=$Name}
        if($Version -ne ""){$imgPackage.Version=$Version}
        if($Language -ne ""){$imgPackage.Language=$Language}
        if($Manufacturer -ne ""){$imgPackage.Manufacturer=$Manufacturer}
        if($Description -ne ""){$imgPackage.Description=$Description}
        if($PkgSourceFlag -ne ""){$imgPackage.PkgSourceFlag=$PkgSourceFlag}
        if($PkgSourcePath -ne ""){$imgPackage.PkgSourcePath=$PkgSourcePath}
       
        

        $imgPackage.Put() | out-null
        $imgPackage.get()
        return $imgPackage
       
    }
}

Function Update-SCCMImagePackage {
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server")][Alias("Server","SmsServer")][System.Object] $SccmServer,
        
        [Parameter(Mandatory=$true)] [String]$PackageID,
        [Parameter(Mandatory=$false)] [String]$Version,
        [Parameter(Mandatory=$false)] [String]$Language,
        [Parameter(Mandatory=$false)] [String]$Manufacturer,
        [Parameter(Mandatory=$false)] [String]$Description,
        [Parameter(Mandatory=$false)] [String]$PkgSourceFlag=2,
        [Parameter(Mandatory=$false)] [String]$PkgSourcePath,
        [Parameter(Mandatory=$false)] [String]$PackageType="4"
       
        
    )
    PROCESS {
        $imgPackage=Get-SCCMImagePackage -SccmServer $SccmServer -Filter ("PackageID='$PackageID'")
        $imgPackage.get()
        #Set properties of image package
        
        if($Version -ne ""){$imgPackage.Version=$Version}
        if($Language -ne ""){$imgPackage.Language=$Language}
        if($Manufacturer -ne ""){$imgPackage.Manufacturer=$Manufacturer}
        if($Description -ne ""){$imgPackage.Description=$Description}
        if($PkgSourceFlag -ne ""){$imgPackage.PkgSourceFlag=$PkgSourceFlag}
        if($PkgSourcePath -ne ""){$imgPackage.PkgSourcePath=$PkgSourcePath}
       
        

        $imgPackage.Put() | out-null
        $imgPackage.get()
        return $imgPackage
       
    }
}

#endregion


# - - - - - - - - - - Boot Image(WinPE)- - - - - - - - - - - - - - -

#region BootImages

Function Get-SCCMBootImagePackage {
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server",ValueFromPipeline=$true)][Alias("Server","SmsServer")][System.Object] $SccmServer,
		[Parameter(Mandatory=$false, HelpMessage="Get package by name")][String] $Name = $null,
		[Parameter(Mandatory=$false, HelpMessage="Get package by PackageID")][String] $PackageID = $null,
        [Parameter(Mandatory=$false, HelpMessage="Optional Filter on query")][String] $Filter = $null
    )
 
    PROCESS {
	
		If ($Name){
			$res = Get-SCCMObject -sccmServer $SccmServer -class "SMS_BootImagePackage" -Filter "Name='$Name'"
		}elseif($PackageID){
			$res = Get-SCCMObject -sccmServer $SccmServer -class "SMS_BootImagePackage" -Filter "PackageID='$PackageID'"
		}else{
		
			$res = Get-SCCMObject -sccmServer $SccmServer -class "SMS_BootImagePackage" -Filter $Filter
		
		}	
	
        return $res
	
       
    }
}

Function New-SCCMBootImagePackage {
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server")][Alias("Server","SmsServer")][System.Object] $SccmServer,        
        [Parameter(Mandatory=$true)] [String]$Name,
        [Parameter(Mandatory=$false)] [String]$AlternateContentProviders,
        [Parameter(Mandatory=$false)] [String]$Architecture,
        [Parameter(Mandatory=$false)] [String]$BackgroundBitmapPath,
        [Parameter(Mandatory=$false)] [String]$ContextID,
        [Parameter(Mandatory=$false)] [String]$Description,
        [Parameter(Mandatory=$false)] [Boolean]$EnableLabShell,
        [Parameter(Mandatory=$false)] [String]$ForcedDisconnectDelay,
        [Parameter(Mandatory=$false)] [Boolean]$ForcedDisconnectEnabled,
        [Parameter(Mandatory=$false)] [String]$ForcedDisconnectNumRetries,
        [Parameter(Mandatory=$false)] [Boolean]$IgnoreAddressSchedule,
        [Parameter(Mandatory=$false)] [String]$ImageIndex,
        [Parameter(Mandatory=$false)] [String]$ImagePath,
        [Parameter(Mandatory=$false)] [String]$ImageProperty,
        [Parameter(Mandatory=$false)] [String]$Language,
        [Parameter(Mandatory=$false)] [String]$Manufacturer,
        [Parameter(Mandatory=$false)] [String]$MIFFilename,
        [Parameter(Mandatory=$false)] [String]$MIFName,
        [Parameter(Mandatory=$false)] [String]$MIFPublisher,
        [Parameter(Mandatory=$false)] [String]$MIFVersion,
        [Parameter(Mandatory=$false)] [String]$PackageType,
        [Parameter(Mandatory=$false)] [String]$PkgFlags,
        [Parameter(Mandatory=$false)] [String]$PkgSourceFlag,
        [Parameter(Mandatory=$false)] [String]$PkgSourcePath,
        [Parameter(Mandatory=$false)] [String]$PreferredAddressType,
        [Parameter(Mandatory=$false)] [String]$Priority,
        #SMS_Driver_Details ReferencedDrivers[]
        [Parameter(Mandatory=$false)] [String]$RefreshPkgSourceFlag,
        [Parameter(Mandatory=$false)] [String]$ShareName,
        [Parameter(Mandatory=$false)] [String]$ShareType,
        [Parameter(Mandatory=$false)] [String]$StoredPkgPath,
        [Parameter(Mandatory=$false)] [String]$StoredPkgVersion,
        [Parameter(Mandatory=$false)] [String]$Version
       
        
    )
    PROCESS {
        $strServer = $SccmServer.machine
        $strNamespace= $SccmServer.namespace
        $bootImagePackageClass = [WmiClass]("\\$strServer\" + "$strNameSpace" + ":SMS_BootImagePackage")
        $bootImg=$bootImagePackageClass.CreateInstance()
        
        if($AlternateContentProviders -ne ""){$bootImg.AlternateContentProviders=$AlternateContentProviders}
        if($Architecture -ne ""){$bootImg.Architecture=$Architecture}
        if($BackgroundBitmapPath -ne ""){$bootImg.BackgroundBitmapPath=$BackgroundBitmapPath}
        if($ContextID -ne ""){$bootImg.ContextID=$ContextID}
        if($Description -ne ""){$bootImg.Description=$Description}
        if($EnableLabShell -ne ""){$bootImg.EnableLabShell=$EnableLabShell}
        #DELif($AlternateContentProviders -ne ""){$bootImg.ExtendedData$ExtendedDataSize
        if($ForcedDisconnectDelay -ne ""){$bootImg.ForcedDisconnectDelay=$ForcedDisconnectDelay}
        if($ForcedDisconnectEnabled -ne ""){$bootImg.ForcedDisconnectEnabled=$ForcedDisconnectEnabled}
        if($ForcedDisconnectNumRetries -ne ""){$bootImg.ForcedDisconnectNumRetries=$ForcedDisconnectNumRetries}
        if($IgnoreAddressSchedule -ne ""){$bootImg.IgnoreAddressSchedule=$IgnoreAddressSchedule}
        if($ImageIndex -ne ""){$bootImg.ImageIndex=$ImageIndex}
        if($ImagePath -ne ""){$bootImg.ImagePath=$ImagePath}
        if($ImageProperty -ne ""){$bootImg.ImageProperty=$ImageProperty}
        if($Language -ne ""){$bootImg.Language=$Language}
        if($Manufacturer -ne ""){$bootImg.Manufacturer=$Manufacturer}
        if($MIFFilename -ne ""){$bootImg.MIFFilename=$MIFFilename}
        if($MIFName -ne ""){$bootImg.MIFFilename=$MIFName}
        if($MIFPublisher -ne ""){$bootImg.MIFPublisher=$MIFPublisher}
        if($MIFVersion -ne ""){$bootImg.MIFVersion=$MIFVersion}
        if($Name -ne ""){$bootImg.Name=$Name}
        if($PackageType -ne ""){$bootImg.PackageType=$PackageType}
        if($PkgFlags -ne ""){$bootImg.PkgFlags=$PkgFlags}
        if($PkgSourceFlag -ne ""){$bootImg.PkgSourceFlag=$PkgSourceFlag}
        if($PkgSourcePath -ne ""){$bootImg.PkgSourcePath=$PkgSourcePath}
        if($PreferredAddressType -ne ""){$bootImg.PreferredAddressType=$PreferredAddressType}
        if($Priority -ne ""){$bootImg.Priority=$Priority}
        #SMS_Driver_Details ReferencedDrivers[]
        if($RefreshPkgSourceFlag -ne ""){$bootImg.RefreshPkgSourceFlag=$RefreshPkgSourceFlag}
        if($ShareName -ne ""){$bootImg.ShareName=$ShareName}
        if($ShareType -ne ""){$bootImg.ShareType=$ShareType}
        if($StoredPkgPath -ne ""){$bootImg.StoredPkgPath=$StoredPkgPath}
        if($StoredPkgVersion -ne ""){$bootImg.StoredPkgVersion=$StoredPkgVersion}
        if($Version -ne ""){$bootImg.Version=$Version}

        $bootImg.Put() |out-null
        $bootImg.get()
        return $bootImg
       
    }
}

Function Update-SCCMBootImagePackage {
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server")][Alias("Server","SmsServer")][System.Object] $SccmServer,        
        [Parameter(Mandatory=$true)] [String]$PackageID,
        [Parameter(Mandatory=$false)] [String]$BackgroundBitmapPath,
        [Parameter(Mandatory=$false)] [String]$Description,
        [Parameter(Mandatory=$false)] [Boolean]$EnableLabShell,
        [Parameter(Mandatory=$false)] [String]$ImageIndex,     
        [Parameter(Mandatory=$false)] [String]$Language,
        [Parameter(Mandatory=$false)] [String]$Manufacturer,                    
        [Parameter(Mandatory=$false)] [String]$Version
       
        
    )
    PROCESS {
       
       
        $bootImg=Get-SCCMBootImagePackage -SccmServer $SccmServer -Filter ("PackageID='$PackageID'")
        $bootImg.get()
       
        if($BackgroundBitmapPath -ne ""){$bootImg.BackgroundBitmapPath=$BackgroundBitmapPath}     
        if($Description -ne ""){$bootImg.Description=$Description}
        if($EnableLabShell -ne ""){$bootImg.EnableLabShell=$EnableLabShell}        
        if($ImageIndex -ne ""){$bootImg.ImageIndex=$ImageIndex}       
        if($Language -ne ""){$bootImg.Language=$Language}
        if($Manufacturer -ne ""){$bootImg.Manufacturer=$Manufacturer}                             
        if($Version -ne ""){$bootImg.Version=$Version}

        $bootImg.Put() |out-null
        $bootImg.get()
        return $bootImg
       
    }
}
 
Function Add-SCCMDistributionPoint {
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server")][Alias("Server","SmsServer")][System.Object] $SccmServer,
        [Parameter(Mandatory=$true, HelpMessage="PackageID")][String] $DPPackageID,
        [Parameter(Mandatory=$false, HelpMessage="DistributionPoint Servername")][String]$DPName = "",
        [Parameter(Mandatory=$false, HelpMessage="All DistributionPoints of SiteCode")][String] $DPsSiteCode = "",
        [Parameter(Mandatory=$false, HelpMessage="Distribution Point Group")][String] $DPGroupName = "",
        [Switch] $AllDPs
    )
    PROCESS {
        if ($DPName -ne "") {
            $Resource = Get-SCCMObject -SccmServer $SccmServer -class SMS_SystemResourceList -Filter "RoleName = 'SMS Distribution Point' and Servername = '$DPName'"
            $DPClass = [WMICLASS]"\\$($SccmServer.Machine)\$($SccmServer.Namespace):SMS_DistributionPoint"
            $newDistributionPoint = $DPClass.createInstance()
            $newDistributionPoint.PackageID = $DPPackageID
            $newDistributionPoint.ServerNALPath = $Resource.NALPath
            $newDistributionPoint.SiteCode = $Resource.SiteCode
            $newDistributionPoint.Put()
            $newDistributionPoint.Get()
            Write-Verbose "Assigned Package: $($newDistributionPoint.PackageID)"
        }
        if ($DPsSiteCode -ne "") {
            $ListOfResources = Get-SCCMObject -SccmServer $SccmServer -class SMS_SystemResourceList -Filter "RoleName = 'SMS Distribution Point' and SiteCode = '$DPsSiteCode'"
            $DPClass = [WMICLASS]"\\$($SccmServer.Machine)\$($SccmServer.Namespace):SMS_DistributionPoint"
            $newDistributionPoint = $DPClass.createInstance()
            $newDistributionPoint.PackageID = $DPPackageID
            foreach ($resource in $ListOfResources) {
                $newDistributionPoint.ServerNALPath = $Resource.NALPath
                $newDistributionPoint.SiteCode = $Resource.SiteCode
                $newDistributionPoint.Put()
                $newDistributionPoint.Get()
                Write-Verbose "Assigned Package: $($newDistributionPoint.PackageID)"
            }
        }
        if ($DPGroupName -ne "") {
            $DPGroup = Get-SCCMObject -sccmserver $SccmServer -class SMS_DistributionPointGroup -Filter "sGroupName = '$DPGroupName'"
            $DPGroupNALPaths = $DPGroup.arrNALPath
            $DPClass = [WMICLASS]"\\$($SccmServer.Machine)\$($SccmServer.Namespace):SMS_DistributionPoint"
            $newDistributionPoint = $DPClass.createInstance()
            $newDistributionPoint.PackageID = $DPPackageID
            foreach ($DPGroupNALPath in $DPGroupNALPaths) {
                $DPResource = Get-SCCMObject -SccmServer $SccmServer -class SMS_SystemResourceList -Filter "RoleName = 'SMS Distribution Point'" | Where-Object {$_.NALPath -eq $DPGroupNALPath}
                if ($DPResource -ne $null) {
                    Write-Verbose "$DPResource"
                    $newDistributionPoint.ServerNALPath = $DPResource.NALPath
                    Write-Verbose "ServerNALPath = $($newDistributionPoint.ServerNALPath)"
                    $newDistributionPoint.SiteCode = $DPResource.SiteCode
                    Write-Verbose "SiteCode = $($newDistributionPoint.SiteCode)"
                    $newDistributionPoint.Put()
                    $newDistributionPoint.Get()
                    Write-Host "Assigned Package: $($newDistributionPoint.PackageID) to $($DPResource.ServerName)"
                } else {
                    Write-Host "DP not found = $DPGroupNALPath"
                }
            }
        }
        if ($AllDPs) {
            $ListOfResources = Get-SCCMObject -SccmServer $SccmServer -class SMS_SystemResourceList -Filter "RoleName = 'SMS Distribution Point'"
            $DPClass = [WMICLASS]"\\$($SccmServer.Machine)\$($SccmServer.Namespace):SMS_DistributionPoint"
            $newDistributionPoint = $DPClass.createInstance()
            $newDistributionPoint.PackageID = $DPPackageID
            foreach ($resource in $ListOfResources) {
                $newDistributionPoint.ServerNALPath = $Resource.NALPath
                $newDistributionPoint.SiteCode = $Resource.SiteCode
                $newDistributionPoint.Put()
                $newDistributionPoint.Get()
                Write-Verbose "Assigned Package: $($newDistributionPoint.PackageID) $($newDistributionPoint.ServerNALPath)"
            }
        }
    }
}
 
Function Update-SCCMDriverPkgSourcePath {
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server")][Alias("Server","SmsServer")][System.Object] $SccmServer,
        [Parameter(Mandatory=$true, HelpMessage="Current Path", ValueFromPipeline=$true)][String] $currentPath,
        [Parameter(Mandatory=$true, HelpMessage="New Path", ValueFromPipeline=$true)][String] $newPath
    )
 
    PROCESS {
        Get-SCCMDriverPackage -sccmserver $SccmServer | Where-Object {$_.PkgSourcePath -ilike "*$($currentPath)*" } | Foreach-Object {
            $newSourcePath = ($_.PkgSourcePath -ireplace [regex]::Escape($currentPath), $newPath)
            Write-Verbose "Changing from '$($_.PkgSourcePath)' to '$($newSourcePath)' on $($_.PackageID)"
            $_.PkgSourcePath = $newSourcePath
            $_.Put() | Out-Null
        }
    }
}
 
Function Update-SCCMPackageSourcePath {
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server")][Alias("Server","SmsServer")][System.Object] $SccmServer,
        [Parameter(Mandatory=$true, HelpMessage="Current Path", ValueFromPipeline=$true)][String] $currentPath,
        [Parameter(Mandatory=$true, HelpMessage="New Path", ValueFromPipeline=$true)][String] $newPath
    )
 
    PROCESS {
        Get-SCCMPackage -sccmserver $SccmServer | Where-Object {$_.PkgSourcePath -ilike "*$($currentPath)*" } | Foreach-Object {
            $newSourcePath = ($_.PkgSourcePath -ireplace [regex]::Escape($currentPath), $newPath)
            Write-Verbose "Changing from '$($_.PkgSourcePath)' to '$($newSourcePath)' on $($_.PackageID)"
            $_.PkgSourcePath = $newSourcePath
            $_.Put() | Out-Null
        }
    }
}
 

#EndRegion

#-------------------- Computer Assocciation -------------------

#region Computer Association

Function get-SCCMComputerAssociation {
	<#
.SYNOPSIS
  Get the current computer associations
.DESCRIPTION
  Will return all the current computer associations
.PARAMETER SccmServer
   Sccm Connection object created with Connect-SccmServer
.EXAMPLE
	$Connection = Connect-SccmServer "MyServer01"
	Get-SCCMComputerAssociation -SccmServer $Connection
  	
.NOTES
	Author: Stéphane van Gulick
	version: 1.0
	History:
.LINK
	www.PowerShellDistrict.com
#>
	
 	[CmdletBinding()]
	Param(
		[Parameter(mandatory=$true)]$SccmServer,
		[Parameter(mandatory=$false)]$SourceComputerName
	)
	if (!($PSBoundParameters.Keys -contains "SourceComputerName"))
		{
			Get-SCCMObject -class SMS_StateMigration -SccmServer $SccmServer
		}
	else{
		
		Get-SCCMObject -class SMS_StateMigration -SccmServer $SccmServer -Filter "SourceName='$SourceComputerName'"
	}
}

Function New-SccmComputerAssociation {
	<#
.SYNOPSIS
  Creates a new Computer Assocation.
.DESCRIPTION
  Creates a new computer association for the USMT migration.
.PARAMETER SccmServer
   Sccm Connection object created with Connect-SccmServer
.EXAMPLE
	$Connection = Connect-SccmServer "MyServer01"
	New-SCCMComputerAssociation -SccmServer $Connection -SourceComputerID $id
  	
.NOTES
	Author: Stéphane van Gulick
	version: 1.0
	History:
.LINK
	www.PowerShellDistrict.com
#>
	
	[CmdletBinding()]
	Param(
		[Parameter(mandatory=$true)]$SourcecomputerId,
		[Parameter(mandatory=$false)]$RestoreComputerId,
		[Parameter(mandatory=$false)][Switch]$InPLace, #Not working for the moment
		[Parameter(mandatory=$true)]$SccmServer
	)
	if ($InPlace)
		{
			Write-Verbose "Creating a in-place association"
			$Computer = Get-SCCMComputer -ResourceID $SourcecomputerId -SccmServer $con
			$wmi = [wmiclass]"\\$($sccmServer.machine)\$($sccmServer.Namespace):SMS_StateMigration"
	
			$Instance = $Wmi.CreateInstance()
			
			$Instance.migrationType = 2
			#Restore Data
				$Instance.RestoreClientResourceID = $Computer.resourceID
				$Instance.RestoreMACAddresses = $Computer.MACAddresses
				$Instance.RestoreName = $Computer.Name
				$Instance.RestoreLastLogonUserName = $Computer.LastLogonUserName
				$Instance.RestoreLastLogonUserDomain = $Computer.LastLogonUserDomain
				
			#Source DAta
				$Instance.SourceName = $Computer.Name
				$Instance.sourceMacAddresses = $Computer.MACAddresses
				$Instance.SourceClientResourceID = $Computer.ResourceId
				$Instance.sourceLastLogonUSername = $Computer.LastLogonUserName
				$Instance.SourceLastLogonUserDomain = $Computer.LastLogonUserDomain
			
			#Confirming changes
			$Instance
				$Instance.put()

		#$association = $wmi.AddAssociation($SourcecomputerId,$RestoreComputerId)
			#$association.put()
	}
	else{
		Write-Verbose "Creating a side-by-side association"
		$wmi = [wmiclass]"\\$($sccmServer.machine)\$($sccmServer.Namespace):SMS_StateMigration"
		$association = $wmi.AddAssociation($SourcecomputerId,$RestoreComputerId)
		return $association
	}
}

Function Remove-SccmComputerAssociation {
	<#
.SYNOPSIS
  Remove a computer assocation.
.DESCRIPTION
  Removes a computer association with the Source and destination ID Computer ID's. 
.PARAMETER SccmServer
   Sccm Connection object created with Connect-SccmServer
.EXAMPLE
	$Connection = Connect-SccmServer "MyServer01"
	Remove-SCCMComputerAssociation -SccmServer $Connection -SourceComputerID $SourceID -RestoreComputerID $RestoreID
  	
.NOTES
	Author: Stéphane van Gulick
	version: 1.0
	History:
.LINK
	www.PowerShellDistrict.com
#>
	
	[CmdletBinding()]
	Param(
		[Parameter(mandatory=$true)]$SourcecomputerId,
		[Parameter(mandatory=$false)]$RestoreComputerId,
		[Parameter(mandatory=$true)]$SccmServer
	)
	$wmi = [wmiclass]"\\$($sccmServer.machine)\$($sccmServer.Namespace):SMS_StateMigration"
	
		$association = $Wmi.DeleteAssociation($SourcecomputerId,$RestoreComputerId)
		
		return $association
		

}

#endregion


#--------------------- Folders -------------------

#Region Folders

Function Get-SCCMFolder {
	<#
.SYNOPSIS
  Get the current SCCM folders.
.DESCRIPTION
  Will return all the SCCM folders currently present on the site server.
.PARAMETER SccmServer
   Sccm Connection object created with Connect-SccmServer
.PARAMETER Name
	Will return the folder with the specefic name.
.PARAMETER ContainerNodeID
	Will return the folder according to the specefic containerNodeID
.EXAMPLE
	$Connection = Connect-SccmServer "MyServer01"
	Get-SCCMFolder -SccmServer $Connection -name "Drivers"
  	
.NOTES
	Author: Stéphane van Gulick
	version: 1.0
	History:
.LINK
	www.PowerShellDistrict.com
#>

    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server",ValueFromPipeline=$true)][Alias("Server","SmsServer")][System.Object] $SccmServer,
		[Parameter(Mandatory=$false, HelpMessage="Name of folder")][String] $Name,
		[Parameter(Mandatory=$false, HelpMessage="ID of folder")][String] $ContainderNodeID,
        [Parameter(Mandatory=$false, HelpMessage="Optional Filter on query")][String] $Filter = $null
    )
process {

		
		switch ($PSBoundParameters.keys){
		("Name"){	$Result = Get-SCCMObject -sccmServer $SccmServer -class "SMS_ObjectContainerNode" -Filter "Name='$name'"; break}
		("ContainderNodeID"){$Result = Get-SCCMObject -sccmServer $SccmServer -class "SMS_ObjectContainerNode" -Filter "ContainderNodeID = $ContainderNodeID'" ; break}
		
		Default {$Result = Get-SCCMObject -sccmServer $SccmServer -class "SMS_ObjectContainerNode" -Filter $filter}
		}
        return $Result
    
}



}

Function New-SCCMFolder {
	<#
.SYNOPSIS
  Create a new SCCM folder.
.DESCRIPTION
  Creates a NEW SCCM folder in the Hierachy.
.PARAMETER SccmServer
   Sccm Connection object created with Connect-SccmServer
.PARAMETER Name
	Will return the folder with the specefic name.
.PARAMETER ObjectType
	The object type will define what type of folder it will be (Were it will be created). It can have the one of the following values :
					Package
					advertisment
					Query
					Report
					MeteredProductRule
					ConfigurationItem
					OperatingSystemInstall
					ImagePackage
					BootImagePackage
					TaskSequencePackage
					DeviceSettingPackage
					DriverPackage
					Driver
					SoftwareUpdate
					ConfigurationItem
					
.EXAMPLE
	$Connection = Connect-SccmServer "MyServer01"
	New-SCCMFolder -SccmServer $Connection -name "Dell" -objectType "Driver" 
  	
.NOTES
	Author: Stéphane van Gulick
	version: 1.0
	History:
.LINK
	www.PowerShellDistrict.com
#>
	
	
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server",ValueFromPipeline=$true)][Alias("Server","SmsServer")][System.Object] $SccmServer,
		[Parameter(Mandatory=$true, HelpMessage="Name of folder")][String] $Name,
		[Parameter(Mandatory=$false, HelpMessage="Parent containder node ID of folder")][String] $ParentContainderNodeID,
		[Parameter(Mandatory=$false, HelpMessage="object type")][String][validateset("Package","advertisment","Query","Report","MeteredProductRule","ConfigurationItem","OperatingSystemInstall","BootImagePackage","TaskSequencePackage","DeviceSettingPackage","DriverPackage","Driver","SoftwareUpdate","ConfigurationItemBaseLine","ImagePackage")]$ObjectType,
        [Parameter(Mandatory=$false, HelpMessage="FolderFlags")][String] $FolderFlags,
        [Parameter(Mandatory=$false, HelpMessage="IsSearchFolder")][Boolean] $isSearchFolder,
        [Parameter(Mandatory=$false, HelpMessage="SearchString")][String] $SearchString
    )
 
    PROCESS {
		$WMI_ContainerNode = [wmiclass]"\\$($sccmServer.machine)\$($sccmServer.Namespace):SMS_ObjectContainerNode"
		$Instance_ContainerNode = $WMI_ContainerNode.createinstance()
		$Instance_ContainerNode.name = $Name
        $Instance_ContainerNode.FolderFlags=$FolderFlags
        $Instance_ContainerNode.SearchFolder=$isSearchFolder
        $Instance_ContainerNode.SearchString=$SearchString
		
		If ($Instance_ContainerNode){
			$Instance_ContainerNode.ParentContainerNodeID = $ParentContainderNodeID
			}
		else{
			$Instance_ContainerNode.ParentContainerNodeID = 0
		}
		
		#Type
				
				switch ($ObjectType){
					("Package") {$Instance_ContainerNode.objectType = 2}
					("advertisment") {$Instance_ContainerNode.objectType = 3}
					("Query") {$Instance_ContainerNode.objectType = 7}
					("Report") {$Instance_ContainerNode.objectType = 8}
					("MeteredProductRule") {$Instance_ContainerNode.objectType = 9}
					("ConfigurationItem") {$Instance_ContainerNode.objectType = 11}
					("OperatingSystemInstall") {$Instance_ContainerNode.objectType = 14}
					("ImagePackage") {$Instance_ContainerNode.objectType = 18}
					("BootImagePackage") {$Instance_ContainerNode.objectType = 19}
					("TaskSequencePackage") {$Instance_ContainerNode.objectType = 20}
					("DeviceSettingPackage") {$Instance_ContainerNode.objectType = 21}
					("DriverPackage") {$Instance_ContainerNode.objectType = 23}
					("Driver") {$Instance_ContainerNode.objectType = 25}
					("SoftwareUpdate") {$Instance_ContainerNode.objectType = 1011}
					("ConfigurationItem") {$Instance_ContainerNode.objectType = 2011}
					Default {$Instance_ContainerNode.objectType = $ObjectType}
				}

		$Instance_ContainerNode.put() | Out-Null
		$Instance_ContainerNode.get()
        return $Instance_ContainerNode
    }
}

Function Remove-SCCMFolder {
	<#
.SYNOPSIS
  Delete a SCCM folder.
.DESCRIPTION
  Deletes a SCCM folder from the hierarchy (Does not delete the content in it :/)
.PARAMETER SccmServer
   Sccm Connection object created with Connect-SccmServer
.PARAMETER Name
	Will delete the folder with the specefic name.				
.EXAMPLE
	$Connection = Connect-SccmServer "MyServer01"
	New-SCCMFolder -SccmServer $Connection -name "Dell" 
  	
.NOTES
	Author: Stéphane van Gulick
	version: 1.0
	History:
.LINK
	www.PowerShellDistrict.com
#>
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server",ValueFromPipeline=$true)][Alias("Server","SmsServer")][System.Object] $SccmServer,
		[Parameter(Mandatory=$false, HelpMessage="Name of folder")][String] $Name,
		[Parameter(Mandatory=$false, HelpMessage="ID of folder")][String] $ContainderNodeID,
        [Parameter(Mandatory=$false, HelpMessage="Optional Filter on query")][String] $Filter = $null
    )
 
    PROCESS {
		
		switch ($PSBoundParameters.keys){
		("Name"){	$Folder = Get-SCCMObject -sccmServer $SccmServer -class "SMS_ObjectContainerNode" -Filter "Name='$name'"; break}
		("ContainderNodeID"){$Folder = Get-SCCMObject -sccmServer $SccmServer -class "SMS_ObjectContainerNode" -Filter "ContainderNodeID = $ContainderNodeID'" ; break}
		
		Default {$Folder = Get-SCCMObject -sccmServer $SccmServer -class "SMS_ObjectContainerNode" -Filter $filter}
		}
		
		$Folder.Delete()
      
    }
}

Function Move-SCCMFolderContent {
<#
.SYNOPSIS
  Create a new SCCM folder.
.DESCRIPTION
  Creates a NEW SCCM folder in the Hierachy.
.PARAMETER SccmServer
   Sccm Connection object created with Connect-SccmServer
.PARAMETER ObjectID
	ID of object to move.
.PARAMETER DestinationID
	ID of destination folder.
.PARAMETER ObjectType
	The object type will define what type of folder it exactly is (Drivers, Software update etc...) . It can have the one of the following values :
					Package
					advertisment
					Query
					Report
					MeteredProductRule
					ConfigurationItem
					OperatingSystemInstall
					ImagePackage
					BootImagePackage
					TaskSequencePackage
					DeviceSettingPackage
					DriverPackage
					Driver
					SoftwareUpdate
					ConfigurationItem
					
.EXAMPLE
	$Connection = Connect-SccmServer "MyServer01"
	Move-SCCMFolderContent -SccmServer $Connection -ObjectID $SourceID -DestinationID $DestID 
  	
.NOTES
	Author: Stéphane van Gulick
	version: 1.0
	History:
.LINK
	www.PowerShellDistrict.com
#>
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server",ValueFromPipeline=$true)][Alias("Server","SmsServer")][System.Object] $SccmServer,
		[Parameter(Mandatory=$false, HelpMessage="Object type to move")][validateset("Package","advertisment","Query","Report","MeteredProductRule","ConfigurationItem","OperatingSystemInstall","BootImagePackage","TaskSequencePackage","DeviceSettingPackage","DriverPackage","Driver","SoftwareUpdate","ConfigurationItemBaseLine","ImagePackage")]$ObjectType,
		[Parameter(Mandatory=$false, HelpMessage="ID of object to move")][String]$ObjectID,
		#[Parameter(Mandatory=$false, HelpMessage="ID of Source folder")]$sourceContainerId,
		[Parameter(Mandatory=$false, HelpMessage="ID of destination folder")]$DestinationContainerId
       
    )
 
    PROCESS {
		
		
		#$ObjectType = $null
		switch ($ObjectType){
					("Package") {$type = 2}
					("advertisment") {$type = 3}
					("Query") {$type = 7}
					("Report") {$type = 8}
					("MeteredProductRule") {$type = 9}
					("ConfigurationItem") {$type = 11}
					("OperatingSystemInstall") {$type = 14}
					("ImagePackage") {$type = 18}
					("BootImagePackage") {$type = 19}
					("TaskSequencePackage") {$type = 20}
					("DeviceSettingPackage") {$type = 21}
					("DriverPackage") {$type = 23}
					("Driver") {$type = 25}
					("SoftwareUpdate") {$type = 1011}
					("ConfigurationItemBaseLine") {$type = 2011}
                   
					Default {$type = $ObjectType}
				}
		
        $sourceContainerId=(Get-SCCMObject -SccmServer $sccm -class "SMS_ObjectContainerItem" -Filter ("InstanceKey='$ObjectID'")).ContainerNodeID
        If(!$sourceContainerId){
            $sourceContainerId="0"
        }

		$Class_ObjectContainer = [wmiclass]"\\$($sccmServer.machine)\$($sccmServer.Namespace):SMS_ObjectContainerItem"
		Write-Verbose "Moving object : $($ObjectID) located in $($sourceContainerId) of Objecttype $($type) to $($DestinationContainerId)"
		$result = $Class_ObjectContainer.MoveMembers($ObjectID, $sourceContainerId, $DestinationContainerId, $type)
    
    return $result.ReturnValue 
		
		
      
    }
}

#EndRegion


#---------------------Helper functions---

#region Helper functions

Function Get-ContentID {
 	[CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true, HelpMessage="SCCM Server",ValueFromPipeline=$true)][Alias("Server","SmsServer")][System.Object] $SccmServer,
		[Parameter(Mandatory=$false, HelpMessage="Get driver by CI_UniqueID")][String] $CI_ID
 	)
		
		$ContentID = (Get-SCCMObject -sccmServer $SccmServer -class "SMS_CIToContent" -Filter "CI_ID='$CI_ID'").ContentID
		return $ContentID 
	
 }

Function Convert-WMITime {
<#
.SYNOPSIS
	Converts a WMI date into and date and time value.
   
.DESCRIPTION
	Converts a WMI date and time value (20120802155521.601556+120) to a normal and human understadable time and date format.
   
.PARAMETER WMITime
	WMI time (e.g : 20120802155521.601556+120)

.PARAMETER Whatif
	Permits to launch this script in "draft" mode. This means it will only show the results without really making generating the files.

.PARAMETER Verbose
	Allow to run the script in verbose mode for debbuging purposes.
   
.EXAMPLE
	convert-WMITime -time 20120802155521.601556+120
	
.EXAMPLE
	"20120802155521.601556+120" | convert-WMITime 

.NOTES
	-Author: Stephane van Gulick
	-Email : 
	-CreationDate: 
	-LastModifiedDate: 02/08/2012
	-Version: 0.3
	-History:

.LINK
	
#>
	Param(
	[Parameter(mandatory=$true,ValueFromPipeLine=$true)]$WmiTime
	)
	#This function converts a WMI date and time value to a "human" understandable format.
	#---------------Begin-----------------------------
	begin{
	}
	#---------------Process-----------------------------
	Process{
	$ComprehensibleDateTime = [System.Management.ManagementDateTimeConverter]::ToDateTime($WmiTime)
	}
	#--------------- End-----------------------------
	end{
		#returning the generated time format.
		Return $ComprehensibleDateTime
	}
}

Function ConvertTo-WMITime {
<#
.SYNOPSIS
	Converts a normal date format to a WMI date and time value.
   
.DESCRIPTION
	Insert a date / time format input and a WMI date format (Eg: 20120802155521.601556+120)
   
.PARAMETER Time
	A normal date and time format ( get-date)

.PARAMETER Whatif
	Permits to launch this script in "draft" mode.

.PARAMETER Verbose
	Allow to run the script in verbose mode for debbuging purposes.
   
.EXAMPLE
	ConvertTo-WMITime -time (get-date)
	
.EXAMPLE
	get-date | convert-ToWMITime -time 

.NOTES
	-Author: Stephane van Gulick
	-Email : 
	-CreationDate: 
	-LastModifiedDate: 02/08/2012
	-Version: 0.4
	-History:

.LINK
	 
#>
	[cmdletbinding()]
	Param(
	[Parameter(mandatory=$true,ValueFromPipeline=$true)]$Time
	)
	
	#---------------Begin-----------------------------
	begin{
	}
	#---------------Process-----------------------------
	Process{
	$WmiTime = [System.Management.ManagementDateTimeConverter]::ToDmtfDateTime($Time)
	}
	#--------------- End-----------------------------
	end{
		#returning the generated time format.
		Return $Wmitime
	}
}

Function Convert-SQLTimeToWMITime {
<#
.SYNOPSIS
	Converts a time string received from a SQL query to a WMI date and time value.
   
.DESCRIPTION
	Insert a date / time format input and a WMI date format (Eg: 20120802155521.601556+120)
   
.PARAMETER Time
	SQL time string

.PARAMETER Whatif
	Permits to launch this script in "draft" mode.

.PARAMETER Verbose
	Allow to run the script in verbose mode for debbuging purposes.
   
.EXAMPLE
	convert-ToWMITime -time (get-date)
	
.EXAMPLE
	06.12.2013 16:24:00 | convertSQLTime-ToWMITime 

.NOTES
	-Author: Stephane van Gulick
	-Email : 
	-CreationDate: 19/12/2013
	-LastModifiedDate: 19/12/2013
	-Version: 0.4
	-History:

.LINK
	 
#>
	[cmdletbinding()]
	Param(
	[Parameter(mandatory=$true,ValueFromPipeline=$true)][STRING]$Time
	)
	
	#---------------Begin-----------------------------
	begin{
	}
	#---------------Process-----------------------------
	Process{
		#Casting the SQL string to datetime ([DateTime]$time) like this does not work, since there is a difference between US DAteTime format and EU time format. 
		#06.12.2013 is the 6 of december in EU format, but 12 of july in US format. #This is why the Get-date must be used.
		$NewTime = Get-Date -Date $Time
		$WmiTime = [System.Management.ManagementDateTimeConverter]::ToDmtfDateTime($NewTime)
	}
	#--------------- End-----------------------------
	end{
		#returning the generated time format.
		Return $Wmitime
	}
}

#endregion

#endregion
