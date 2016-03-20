foreach ($folder in Get-ChildItem | ?{ $_.PSIsContainer })
{
   tfx extension create --manifest-globs vss-extension.json --root $folder 
}