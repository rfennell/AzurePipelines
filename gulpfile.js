var gulp = require('gulp');
var path = require('path');
var del = require('del'); 

var shell = require('shelljs')
var pkgm = require('./package');
var ts = require('gulp-typescript');

var _buildRoot = path.join(__dirname, '_build', 'Tasks');
//var _pkgRoot = path.join(__dirname, '_package');
//var _oldPkg = path.join(__dirname, 'Package');
//var _wkRoot = path.join(__dirname, '_working');

gulp.task('clean', function (cb) {
//	del([_buildRoot, _pkgRoot, _wkRoot, _oldPkg],cb);
	del([_buildRoot],cb);
});

gulp.task('compile', function (cb) {
	var tasksPath = path.join(__dirname, 'Tasks', '**/*.ts');
	var tsResult = gulp.src([tasksPath, 'definitions/*.d.ts'])
		.pipe(ts({
		   declarationFiles: false,
		   noExternalResolve: true,
		   'module': 'commonjs'
		}));
		
	return tsResult.js.pipe(gulp.dest(path.join(__dirname, 'Tasks')));
});

gulp.task('build', ['clean', 'compile'], function () {
	shell.mkdir('-p', _buildRoot);
	return gulp.src(path.join(__dirname, 'Tasks', '**/task.json'))
        .pipe(pkgm.PackageTask(_buildRoot));
});

gulp.task('default', ['build']);


