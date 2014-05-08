nunit-emacs
===========

Helpers for using Nunit with Emacs.


Installation
------------

Put nunit-results.el into your `load-path' and add to your init file:

    (require 'nunit-results)


Usage
-----

    M-x nunit-results-show

Display a formatted report of NUnit test results in a buffer.
Parses TestResult.xml, which should be dropped by running
nunit-console.  Running nunit-console is out of scope of this
package.

    M-x nunit-results-watch

Check TestResult.xml periodically and pop up the results buffer
when there are changes.

    M-x nunit-results-stop-watching

Stop the watcher.
