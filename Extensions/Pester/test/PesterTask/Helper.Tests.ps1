

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

        it "Can parse block with trailing ;" {
            $actual = Get-HashtableFromString -line "@{Path='C:\path\123'; Parameters=@{param1='111'; param2='222'}};"
            $actual.Path | Should -Be "C:\path\123"
            $actual.Parameters.param1 | Should -Be "111"
            $actual.Parameters.param2 | Should -Be "222"
        }

        it "Can parse three part block 1" {
            $actual = Get-HashtableFromString -line "@{Path='C:\path\123';  x='y'; Parameters=@{param1='111'; param2='222'}}"
            $actual.Path | Should -Be "C:\path\123"
            $actual.Parameters.param1 | Should -Be "111"
            $actual.Parameters.param2 | Should -Be "222"
            $actual.x | Should -Be "y"
        }

        it "Can parse three part block 2" {
            $actual = Get-HashtableFromString -line "@{Path='C:\path\123'; Parameters=@{param1='111'; param2='222'}; x='y'}"
            $actual.Path | Should -Be "C:\path\123"
            $actual.Parameters.param1 | Should -Be "111"
            $actual.Parameters.param2 | Should -Be "222"
            $actual.x | Should -Be "y"
        }
        it "Can parse hashtable with ; in a value" {
            $actual = Get-HashtableFromString -line "@{Path='.\tests\script.tests.ps1'; Parameters=@{someVar='this'}},@{Path='.\tests\script2.tests.ps1'; Parameters=@{otherparam='foo.txt;bar.txt'}}"
            $actual.GetType().BaseType | Should -Be "Array"
            $actual[0].Path | Should -Be '.\tests\script.tests.ps1'
            $actual[0].Parameters.SomeVar | Should -Be 'this'
            $actual[1].Path | Should -Be '.\tests\script2.tests.ps1'
            $actual[1].Parameters.otherparam | Should -Be 'foo.txt;bar.txt'
        }
        it "Can parse hashtable with commas in a value" {
            $actual = Get-HashtableFromString -line "@{Path='.\tests\script.tests.ps1'; Parameters=@{someVar='this'}},@{Path='.\tests\script2.tests.ps1'; Parameters=@{otherparam='foo.txt;bar.txt';Param2='ValueGoesHere'}},@{path='.\tests\script3.tests.ps1';Parameters=@{inputvar='var,this,string'}}"
            $actual.GetType().BaseType | Should -Be "Array"
            $actual[0].Path | Should -Be '.\tests\script.tests.ps1'
            $actual[0].Parameters.SomeVar | Should -Be 'this'
            $actual[1].Path | Should -Be '.\tests\script2.tests.ps1'
            $actual[1].Parameters.otherparam | Should -Be 'foo.txt;bar.txt'
            $actual[1].Parameters.Param2 | Should -Be 'ValueGoesHere'
            $actual[2].Path | Should -Be '.\tests\script3.tests.ps1'
            $actual[2].Parameters.inputvar | Should -Be 'var,this,string'
        }


    }
}
