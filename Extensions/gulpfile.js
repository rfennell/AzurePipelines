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
	del('*.vsix');
});

gulp.task('build', ['clean'], function () {
  var folders = getFolders(__dirname);  
  folders.forEach(
      function (value) 
      { 
          exec('tfx extension create --manifest-globs vss-extension.json --root ' + value);
      });
});

gulp.task('default', ['build']);


