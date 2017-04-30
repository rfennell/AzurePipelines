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
	del('VersionAssembliesTask/*.js');
    
});

gulp.task('copy', function () {
    del('VersionAssembliesTask//node_modules');
    gulp.src(['VersionAssembliesTask.src/node_modules/**/*']).pipe(gulp.dest('VersionAssembliesTask/node_modules'));
});


gulp.task('build', function () {
    exec('tsc -p VersionAssembliesTask.src/.' );
});

gulp.task('default', ['build']);
