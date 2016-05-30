#lang racket

(require net/url)
(require (planet ryanc/webapi:1:=1/oauth2))
(require json)
(require net/uri-codec)
(require gregor)
(require gregor/period)

; interface to Google Calendar for project reporting purposes.
; Fred Martin, fredm@cs.uml.edu, May 30 2016

; known issue: only first 2500 search results will be found
;              (the code needed to follow down pages of results isn't written)

; from your Google Developers Console; see below
(define client-id "your-ID-here")
(define client-secret "your-secret-here")

; first time running, set to #t
; then to save time re-running, set renew to false and copy in the saved-token
; gotten by evaluating (send myoauth2 headers)
(define renew #t)
(define saved-token "Authorization: Bearer ya29.CjHyAv-70L4OBmnVfQ4OIlMW5Kh3vQ7fgjtKbNjZTcdGfhctMaYMMXjOr6R46Dxu1jSr")

; parameters for calendar events search
(define search-string "foo") ; replace with your identifier for your project
(define start-date "2015-05-27")
(define end-date "2016-06-01")

; location of output file
(define filename "/tmp/out.csv")

; this will display results (try in REPL):
;(map format-event myeventitems)

; RUN THIS PROCEDURE :)
(define (run-job)
  (let ((out (open-output-file filename #:mode 'text #:exists 'replace)))
    (begin
      (write "DATE" out)(display "," out)(write "DESCRIPTION" out)
      (display "," out)(writeln "HOURS" out)
      (for ((line (map format-event myeventitems)))
        (begin
          (for ((item line))
            (begin
              (write item out)
            (display "," out)))
          (displayln "" out)))
      (close-output-port out))))


; TO SET UP YOUR OWN API SERVICE
; to go Google Developers Console and make a project
; go to Dashboard > Explore other services > Enable APIs and get credentials like keys
; then Google Apps APIs > Calendar API (and enable it)
; then in the left-column menu, Credentials
; then Create credentials > Oauth client ID > Other
; then copy the client ID and secret into this procedure.
(define google-client
  (oauth2-client
   #:id client-id
   #:secret client-secret))

; to get an access token to use the google-client:
; 
; set renew to true
; evaluate buffer and you should get a redirect to your system web browser
; approve permissions in web browser
; sometimes it fails to communicate back with the temporary localhost web server
; that gets launched
; keep trying until it succeeds, then evaluate:
;   (send myoauth2 headers)
; and copy the new bearer token into the else position of the (if renew...) statement.
; then set renew to false.

; alternately
; evaluate this:
;   (send google-auth-server get-auth-request-url #:client google-client #:scopes '("https://www.googleapis.com/auth/drive"))
; go to the URL provided and authorize permissions
; then copy the auth code into this and evaluate it:
;   (send (oauth2/auth-code google-auth-server google-client "<auth-code-here>") headers)
; and copy the new bearer string into the token setting below.


(define myoauth2 '())
(define token '())

(if renew
    (begin 
      (set! myoauth2 (oauth2/request-auth-code/browser
                        google-auth-server
                        google-client
                        '("https://www.googleapis.com/auth/calendar.readonly")
                        ))
      (set! token (send myoauth2 headers)))
    (set! token (list saved-token)))

; have to do (send myoauth2 validate!) before (send myoauth2 get-scopes) will work.


; perform search of primary calendar, returning hash with calendar items in 'items
; 1st arg - search string (e.g. "foo")
; 2nd arg - start time string (e.g. "2016-01-01")
; 3rd arg - send time string (e.g. "2016-07-01") 
(define (list-events . args)
  (let ((q (if (not (null? args)) (car args) #f))
        (start (if (> (length args) 1) (string-append (cadr args) "T00:00:01-05:00") #f))
        (end (if (> (length args) 2) (string-append (caddr args) "T00:00:01-05:00") #f)))
    (read-json
     (get-pure-port
      (string->url (string-append
                    "https://www.googleapis.com/calendar/v3/calendars/primary/events/?"
                    "orderBy=startTime&singleEvents=true"
                    (if q (string-append "&q=" q) "")
                    (if start (string-append "&timeMin=" (form-urlencoded-encode start)) "")
                    (if end (string-append "&timeMax=" (form-urlencoded-encode end)) "")
                    "&maxResults=2500"))
      token))))

(define myevents (list-events search-string start-date end-date))

; get a list of the individual calendar items
(define myeventitems (hash-ref myevents 'items))

; for testing
(define myevent (car myeventitems))

(define (start-time-moment event)
  (iso8601/tzid->moment
   (google-time-hash->iso8601-str (hash-ref event 'start))))

(define (end-time-moment event)
  (iso8601/tzid->moment
   (google-time-hash->iso8601-str (hash-ref event 'end))))

(define (description event)
  (hash-ref event 'description ""))

(define (format-event event)
  (let* ((start (start-time-moment event))
         (end (end-time-moment event))
         (minutes (period-ref
                   (period-between start end '(minutes))
                   'minutes)))
  (list
   (~t start "yyyy-MM-dd")
   (description event)
   (number->string (/ minutes 60.)))))

; ok this is pretty unfortunate
; sometimes google provides the alpha TZ identifier in the start or end date hash,
;   and sometimes not.
; if it is provided, the hash looks like this:
;
;          #hasheq((dateTime . "2016-03-28T14:00:00-04:00")
;                  (timeZone . "America/New_York")))
;
; if not, then the timeZone object is missing:
;
;          #hasheq((dateTime . "2016-03-30T20:00:00-04:00"))
;
; so I guess the strategy is to use [tz-str] if it exists,
;   or hard-code "America/New_York" if not.
;
; there is also an issue dealing with whole-day events,
; which have only a 'date (not a 'dateTime)
; in this case, we'll set them to midnight.
(define (google-time-hash->iso8601-str google-time-hash)
  (let* ((date (hash-ref google-time-hash 'dateTime #f)) ; date-time string or #f if whole-day event
         (date-time (if date date (string-append (hash-ref google-time-hash 'date) "T00:00:00-04:00"))) ; use prior or massage whole-day
         (time-zone (hash-ref google-time-hash 'timeZone "America/New_York")))
    (string-append date-time "[" time-zone "]")))
