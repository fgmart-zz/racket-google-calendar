# racket-google-calendar
Reads Google Calendar events and creates a billing report. Implemented in the Racket language.

I do some consulting and record my work in Google calendar. For each work-session, I create a Calendar item with a unique name for the project, set the duration of the item to be the period of work, and fill in notes in the item's Description field.

This tool searches for events in your primary calendar that match a given search string, and then creates a CSV file with an entry for each event: date, description, and duration (in hours).

To use, you must set up an OAuth 2.0 client in your Google Developer Console with access to the Google Calendar API. There are detailed instructions in the source file; you must copy in your client's ID and secret.

Then you modify some global variables for your report:

```lisp
; parameters for calendar events search
(define search-string "foo") ; replace with your identifier for your project
(define start-date "2015-05-27")
(define end-date "2016-06-01")
```
and
```lisp
; location of output file
(define filename "/tmp/out.csv")
```
and then you can perform the Calendar search and output file creation:
```lisp
(run-job)
```

You'll get output like this in the CSV:
```csv
"DATE","DESCRIPTION","HOURS"
"2015-07-11","parent session","0.8333333333333334",
"2015-09-10","chairs meeting","1.3333333333333333",
"2015-10-03","fall open house","6.0",
```

The project is implemented in [Racket](http://racket-lang.org).
