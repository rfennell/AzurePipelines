
# Check that the required powershell module is loaded if it is remove it as it might be an older version
if ((get-module -name ApplyVersionToManifest ) -ne $null)
{
  remove-module ApplyVersionToManifest 
} 

write-warning "PSScriptRoot is $PSScriptRoot"
import-module "$PSScriptRoot\..\task\ApplyVersionToManifest.psm1"

Describe "Version number split tests" {

    It "should be able to get version name" {
        $return = Get-VersionName -Format "{1}.{2}" -Version "1.2.3.4"
        $return | Should be "1.2"
    }

    It "should be able to get version code" {
        $return = Get-VersionCode -Format "{3}{4}" -Version "1.2.3.4"
        $return | Should be "34"
    }

} 

Describe "File update tests" {

    BeforeEach {
        copy-item "testdata/sample.xml.initial" "testdata/sample.xml"
    }
   
    AfterEach {
       remove-item "testdata/sample.xml"
    }

    It "should be able to update a file" {
        Update-ManifestFile -filename "testdata/sample.xml" -versionCode "34" -versionName "1.2"
        $expected = Get-Content "testdata/sample.xml.expected"
        $actual = Get-Content "testdata/sample.xml"
        $actual | Should be $expected
    }
   
} 