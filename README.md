A simple paint program that creates animated gifs.

Live Demo
---------

Try it out at http://pixelcycle.appspot.com/


Setting up a Development Environment
------------------------------------

Pixelcycle is written in Dart and Go and runs on App Engine. You will need the Dart SDK
and the webdev command for Dart development, and the gcloud command for App Engine.

For Dart development, run `webdev serve`. Then visit http://localhost:8080/main.html

After a few seconds looking at a page with a broken link, the compiler will finish and
PixelCycle will start up with an empty canvas. You will be able to create an animation
but the Save button won't work.

To test loading and saving animations, you will need to run a development instance of App Engine.

First, build the app by running `webdev build`. Then run dev_appserver with a command like:

  {path-to-gcloud-sdk}/bin/dev_appserver.py build/app.yaml

Then try it out at http://localhost:8080/.
