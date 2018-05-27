param (
    $TestValue
)

Describe 'Main tests for Parameters.Tests.ps1' {
    It "Should correctly output $TestValue as `$TestValue" {
        $TestValue | Should -Be $TestValue
    }
}
