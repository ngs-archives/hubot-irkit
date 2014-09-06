gulp       = require 'gulp'
gutil      = require 'gulp-util'
coffee     = require 'gulp-coffee'
mocha      = require 'gulp-mocha'
clean      = require 'gulp-clean'
watch      = require 'gulp-watch'
watch      = require 'gulp-watch'
coffeelint = require 'gulp-coffeelint'
watching   = no

require 'coffee-script/register'

gulp.task 'default', ['mocha']

gulp.task 'clean', ->
  gulp
    .src('node_modules', read: no)
    .pipe(clean())

coffeePipes = (pipe)->
  pipe
    .pipe(coffeelint())
    .pipe(coffeelint.reporter())
    .pipe(coffee(bare: yes)
      .pipe(mocha reporter: process.env.MOCHA_REPORTER || 'nyan')
      .on('error', ->
        if watching
          @emit 'end'
        else
          process.exit 1
    ))

gulp.task 'mocha', ->
  coffeePipes gulp.src('spec/*.coffee')

gulp.task 'watch', ->
  gulp
    .src(['src/**/*.coffee', 'spec/*.coffee'])
    .pipe watch (files)->
      watching = yes
      coffeePipes files
