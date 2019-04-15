
$ \#signup .click ->
  $ \#first .fadeOut \fast, -> 
    $ \#second .fadeIn \fast

$ \#signin .click ->
  $ \#second .fadeOut \fast, -> 
    $ \#first .fadeIn \fast

$ ->
  $ "form[name='login']" .validate do
    rules:
      email:
        required: yes
        email: yes
      password:
        required: yes
    messages:
      email: "Please enter a valid email address"
      password:
        required: "Please enter password"
    submitHandler: (form) ->
      form.submit!

$ ->
  "form[name='registration']" .validate do
    rules:
      firstname: "required"
      lastname: "required"
      email:
        required: yes
        email: yes
      password:
        required: yes
        minlength: 8
    messages:
      firstname: "Please enter your firstname"
      lastname: "Please enter your lastname"
      password:
        required: "Please provide a password"
        minlength: "Your password must be at least 5 characters long"
      email: "Please enter a valid email address"
    submitHandler: (form) ->
      form.submit!
