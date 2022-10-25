Add-Type -AssemblyName System.Configuration
Add-Type -AssemblyName System.Web


function GenererLicence {
    param (
            [Parameter(Mandatory = $true)]
            [string]$prefixeModule,
            [Parameter(Mandatory = $true)]
            [string]$idEtude
    )

    if ([System.String]::IsNullOrWhiteSpace($prefixeModule) -eq $true -Or [System.String]::IsNullOrWhiteSpace($idEtude) -eq $true)
    {
        return $null;
    }
    $chaineEntree = [System.String]::Format("{0}_{1}", $prefixeModule, $idEtude);
    $input = [System.Text.Encoding]::UTF8.GetBytes($chaineEntree);
    #un hash d’une clef X donne toujours le même résultat, quelque soit la machine
    $array = [System.Security.Cryptography.SHA384]::Create().ComputeHash($input);

    # traduction du hash
    $total = "";
    for ($i = 0; $i -lt $array.Length -And $i -lt 4; $i++)
    {
        $total += [System.String]::Format("{0:X2}", $array[$i]);
    }
    return $total;    
}

$sqlfilename = "GetLicense.sql"
$source = 'http://update.csid.be/Gupdate/Download/' + $sqlfilename
$queryFilepath = $PSScriptRoot + "\" + $sqlfilename
$logFilepath = $PSScriptRoot + "\result.log"

if ([System.IO.File]::Exists($logFilepath)) 
{
    del $logFilepath
}

if ([System.IO.File]::Exists($queryFilepath)) 
{
    del $queryFilepath
}

try
{
    Invoke-WebRequest -Uri $source -OutFile $queryFilepath
}
catch 
{
    echo "Telechargement impossible"
}

try
{
	$config = [System.Web.Configuration.WebConfigurationManager]::OpenWebConfiguration("/inot.be")
	$connectionString = $config.ConnectionStrings.ConnectionStrings.Item('DEFAULT').ConnectionString

    $SqlConnection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
    $SqlConnection.Open();

    $sql = Get-Content -Raw -Path $queryFilepath;
    
    $SqlCmd = New-Object System.Data.SqlClient.SqlCommand($sql, $SqlConnection);
    $SqlCmd.Connection = $SqlConnection
    $SqlCmd.CommandType = [System.Data.CommandType]::Text
    $SqlCmd.CommandTimeout = 2000;

    $sqloutreader = $SqlCmd.ExecuteReader()
    $result = "";
    while($sqloutreader.Read()) 
    {    
        [string]$licenseName = $sqloutreader["license"].ToString()
        [string]$licensekey = $sqloutreader["licensekey"].ToString()
        [string]$StudyId = $sqloutreader["StudyId"].ToString()

        $gen = GenererLicence $licenseName $StudyId

        if($gen -eq $licensekey)
        {
            $result += "$licenseName oui" + [System.Environment]::NewLine
        }
        else
        {
            $result += "$licenseName non" + [System.Environment]::NewLine
        }
    }

    echo $result

    $SqlCmd.Dispose()
}
catch 
{
	echo "Une erreur est survenue lors de l'execution du script " $Error[0]
}
finally
{
  # Make sure the SQL connection closes.
  $SqlConnection.Dispose()
}
