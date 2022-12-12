
// A Handlebars Helper to lookup a PR from an array based on it's last commit Id
/* Usage
{{#forEach commits}}
* **{{truncate this.id 7}}**
{{#with (lookup_PR_by_LastCommitId ../pullRequests this.id)}}
  - Associated PR {{this.pullRequestId}}
{{/with}}
{{/forEach}}
*/

module.exports = {lookup_PR_by_LastCommitId (array, id) {
    return array.find(element => element.lastMergeCommit.commitId === id);
}};