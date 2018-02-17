

Import-Module -Name "$PSScriptRoot\..\..\Task\HelperModule.psm1" -Force

Describe "Testing Helper Functions" {

    Context "Testing Get-HashtableFromString" {

        it "Can parse empty block" {
            $actual = Get-HashtableFromString -line ""
            $actual.GetType() | Should -Be @{}.GetType()
            $actual.count | Should -Be 0
        }

        it "Can parse block with no values but delimiter" {
            $actual = Get-HashtableFromString -line ";"
            $actual.GetType() | Should -Be @{}.GetType()
            $actual.count | Should -Be 0
        }

        it "Cannot parse block with invalid string" {
            $actual = Get-HashtableFromString -line ";"
            $actual.GetType() | Should -Be @{}.GetType()
            $actual.count | Should -Be 0
        }

        it "Can parse two part block" {
            $actual = Get-HashtableFromString -line "@{Path='C:\path\123'; Parameters=@{param1='111'; param2='222'}}"
            $actual.Path | Should -Be "C:\path\123"
            $actual.Parameters.param1 | Should -Be "111"
            $actual.Parameters.param2 | Should -Be "222"
        }

        it "Can parse two hashtable part block" {
            $actual = Get-HashtableFromString -line "@{Parameters1=@{param1='111'; param2='222'}; Parameters2=@{param1='111'; param2='222'}}"
            $actual.Parameters1.param1 | Should -Be "111"
            $actual.Parameters1.param2 | Should -Be "222"
            $actual.Parameters2.param1 | Should -Be "111"
            $actual.Parameters2.param2 | Should -Be "222"
        }

        it "Cannot parse block with non-matching brackets" {
            # need the outer {} for =throw to work
           { Get-HashtableFromString -line "@{Path='C:\path\123'; Parameters=@{param1='111'; param2='222'}" } | Should -Throw # ArgumentOutOfRangeException
        }

        it "Can parse block with trailing ;" {
            $actual = Get-HashtableFromString -line "@{Path='C:\path\123'; Parameters=@{param1='111'; param2='222'}};"
            $actual.Path | Should -Be "C:\path\123"
            $actual.Parameters.param1 | Should -Be "111"
            $actual.Parameters.param2 | Should -Be "222"
        }

        it "Can parse three part block 1" {
            $actual = Get-HashtableFromString -line "@{Path='C:\path\123';  x=y; Parameters=@{param1='111'; param2='222'}}"
            $actual.Path | Should -Be "C:\path\123"
            $actual.Parameters.param1 | Should -Be "111"
            $actual.Parameters.param2 | Should -Be "222"
            $actual.x | Should -Be "y"
        }

        it "Can parse three part block 2" {
            $actual = Get-HashtableFromString -line "@{Path='C:\path\123'; Parameters=@{param1='111'; param2='222'}; x=y}"
            $actual.Path | Should -Be "C:\path\123"
            $actual.Parameters.param1 | Should -Be "111"
            $actual.Parameters.param2 | Should -Be "222"
            $actual.x | Should -Be "y"
        }


    }
}