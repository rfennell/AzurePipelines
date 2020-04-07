[[_TOC_]]
# Release notes for build $defname
**Build Number**  : $($build.buildnumber)
**Build started** : $("{0:dd/MM/yy HH:mm:ss}" -f [datetime]$build.startTime)
**Source Branch** $($build.sourceBranch)

## Associated work items
@@WILOOP@@
#$($widetail.id) [Assigned by: $($widetail.fields.'System.AssignedTo'.displayName)] $($widetail.fields.'System.Title')
@@WILOOP@@

## Associated change sets/commits
@@CSLOOP@@
[$($csdetail.commitid.substring(0,7))](https://dev.azure.com/{org}/{project}/_git/{repo}/commit/$($csdetail.commitid)) $($csdetail.comment)
@@CSLOOP@@
