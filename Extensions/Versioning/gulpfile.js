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
	del('VersionDotNetCoreAssembliesTask/*.js');
    del('VersionDotNetCoreAssembliesTask/*.js.map');

});

gulp.task('copy', function () {
    del('VersionDotNetCoreAssembliesTask//node_modules');
    gulp.src(['VersionDotNetCoreAssembliesTask.src/node_modules/**/*']).pipe(gulp.dest('VersionDotNetCoreAssembliesTask/node_modules'));

});


gulp.task('build', function () {
    exec('tsc -p VersionDotNetCoreAssembliesTask.src/.' );

});

gulp.task('default', ['build']);
