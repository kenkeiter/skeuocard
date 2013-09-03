# Thanks to Jackson Gariety (https://github.com/jacksongariety/) for 
# contributing the initial version of this Gruntfile.

module.exports = (grunt) ->
  # Configure plugins
  grunt.initConfig
    
    express:
      all:
        options:
          port: 8000
          hostname: "0.0.0.0"
          bases: ['.']

    open:
      all:
        path: 'http://localhost:<%= express.all.options.port%>'

    coffee:
      all:
        files:
          "./javascripts/skeuocard.js": "./javascripts/src/skeuocard.coffee"

    sass:
      all:
        options:
          style: 'compressed'
        files:
          "./styles/skeuocard.reset.css": "./styles/src/skeuocard.reset.scss"
          "./styles/skeuocard.css": "./styles/src/skeuocard.scss"
          "./styles/demo.css": "./styles/src/demo.scss"

    uglify:
      all:
        options:
          mangle: false # don't change function names
        files:
          "./javascripts/skeuocard.min.js": "./javascripts/skeuocard.js"

    watch:
      all:
        files: [
          "./javascripts/src/skeuocard.coffee"
          "./styles/src/*.scss"
        ]
        tasks: ["coffee", "sass", "uglify"]
        options:
          livereload: true

  
  # Load plugins
  grunt.loadNpmTasks "grunt-contrib-watch"
  grunt.loadNpmTasks "grunt-contrib-coffee"
  grunt.loadNpmTasks "grunt-contrib-sass"
  grunt.loadNpmTasks "grunt-contrib-uglify"
  grunt.loadNpmTasks "grunt-open"
  grunt.loadNpmTasks "grunt-express"

  # Default task
  grunt.registerTask "default", [
    "express",
    "open",
    "watch"
  ]