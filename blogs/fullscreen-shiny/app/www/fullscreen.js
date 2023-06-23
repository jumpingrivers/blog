$(function() {
    'use strict';

    // If fullscreen is not supported jump right out
    if (!document.fullscreenEnabled) {
      return;
    }

    // Simple helper to return a Boolean indicating whether
    // already in fullscreen mode
    function isFullscreen() {
      return !!document.fullscreenElement;
    }

    // Get all the plot containers
    const $plotContainers = $('.plot-container');


    // Make plots go fullscreen when doubleclicked
    $plotContainers.on('dblclick', function() {
      if (isFullscreen()) { return; }
      this.requestFullscreen();
    });


    // Add keyboard controls
    $(document).on('keydown', function (event) {
      // Get name of key pressed
      const code = event.originalEvent.code;
      // If the user presses something other than Enter or
      // we're already in fullscreen we can jump staight out...
      if (code !== 'Enter' || isFullscreen()) { return; }
      // Find the element that currently has focus
      const focus = document.activeElement;
      // If that element is one of our plots...
      if ($plotContainers.toArray().includes(focus)) {
        // ...make it fullscreen
        focus.requestFullscreen();
      }
    });
});
