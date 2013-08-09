module.exports = (grunt) ->
  # Configure plugins
  grunt.initConfig
    coffee:
      compile:
        files:
          "./javascripts/skeuocard.js": "./javascripts/src/skeuocard.coffee"
    
    sass:
      dist:
        files:
          "./styles/demo.css": "./styles/src/demo.scss"
          "./styles/skeuocard.css": "./styles/src/skeuocard.scss"
          "./styles/skeuocard.reset.css": "./styles/src/skeuocard.reset.scss"
    
    watch:
      update:
        files: [
          "./javascripts/src/skeuocard.coffee",
          "./styles/src/demo.scss",
          "./styles/src/skeuocard.scss",
          "./styles/src/skeuocard.reset.scss"]
        tasks: [
          "coffee",
          "sass"
        ]
        options:
          livereload: true

  
  # Load plugins
  grunt.loadNpmTasks "grunt-contrib-watch"
  grunt.loadNpmTasks "grunt-contrib-coffee"
  grunt.loadNpmTasks "grunt-contrib-sass"
  
  # Default task
  grunt.registerTask "default", "watch"