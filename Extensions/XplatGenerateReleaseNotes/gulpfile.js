var gulp = require('gulp');
var path = require('path');
var del = require('del'); 
var fs = require('fs');

var shell = require('shelljs/global')

function getFolders(dir) {
    return fs.readdirSync(dir)
      .filter(function(file) {
        return fs.statSync(path.join(dir, file)).isDirectory();
      });
}

gulp.task('clean', function () {
	del('XPlatGenerateReleaseNotesTask/*.js');
    
});

gulp.task('copy', function () {
    del('XPlatGenerateReleaseNotesTask//node_modules');
    gulp.src(['XPlatGenerateReleaseNotesTask.src/node_modules/**/*']).pipe(gulp.dest('XPlatGenerateReleaseNotesTask/node_modules'));
});


gulp.task('build', ['clean'], function () {
    exec('tsc -p XPlatGenerateReleaseNotesTask.src/.' );
});

gulp.task('default', ['build']);
