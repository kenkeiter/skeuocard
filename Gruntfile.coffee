module.exports = (grunt) ->
  # Configure plugins
  grunt.initConfig
    coffee:
      compile:
        files:
          "./javascripts/skeuocard.js": "./javascripts/src/skeuocard.coffee"

    watch:
      update:
        files: ["./javascripts/src/skeuocard.coffee"]
        tasks: ["coffee"]
        options:
          livereload: true

  
  # Load plugins
  grunt.loadNpmTasks "grunt-contrib-watch"
  grunt.loadNpmTasks "grunt-contrib-coffee"
  
  # Default task
  grunt.registerTask "default", "watch"