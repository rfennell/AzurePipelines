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

gulp.task('npm', function () {
    process.chdir('XmlFileUpdateTask.src');
    exec('npm install' );
});


gulp.task('clean', function () {
	del('XmlFileUpdateTask/*.js');
	del('XmlFileUpdateTask/*.js.map');
});

gulp.task('copy', function () {
    del('XmlFileUpdateTask//node_modules');
    gulp.src(['XmlFileUpdateTask.src/node_modules/**/*']).pipe(gulp.dest('XmlFileUpdateTask/node_modules'));
});


gulp.task('build', function () {
    exec('tsc -p XmlFileUpdateTask.src/.' );
});

gulp.task('default', ['build']);
