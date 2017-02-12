$Cypress.register "Screenshot", (Cypress, _, $, Promise, moment) ->

  Cypress.on "test:after:hooks", (test, runnable) ->
    if test.err and $Cypress.isHeadless and Cypress.config("screenshotOnHeadlessFailure")
      ## give the UI some time to render the error
      ## because we were noticing that errors were not
      ## yet displayed in the UI when running headlessly
      Promise.delay(75)
      .then =>
        @_takeScreenshot(runnable)

  Cypress.Cy.extend
    _takeScreenshot: (runnable, name, log, timeout) ->
      titles = [runnable.title]

      getParentTitle = (runnable) ->
        if p = runnable.parent
          if t = p.title
            titles.unshift(t)

          getParentTitle(p)

      getParentTitle(runnable)

      props = {
        name:   name
        titles: titles
        testId: runnable.id
      }

      automate = ->
        new Promise (resolve, reject) ->
          fn = (resp) =>
            if e = resp.__error
              err = $Cypress.Utils.cypressErr(e)
              err.name = resp.__name
              err.stack = resp.__stack

              try
                $Cypress.Utils.throwErr(err, { onFail: log })
              catch e
                reject(e)
            else
              resolve(resp.response)

          Cypress.trigger("take:screenshot", props, fn)

      if not timeout
        automate()
      else
        ## need to remove the current timeout
        ## because we're handling timeouts ourselves
        @_clearTimeout()

        automate()
        .timeout(timeout)
        .catch Promise.TimeoutError, (err) ->
          $Cypress.Utils.throwErrByPath "screenshot.timed_out", {
            onFail: log
            args: {
              timeout: timeout
            }
          }

  Cypress.addParentCommand
    screenshot: (name, options = {}) ->
      if _.isObject(name)
        options = name
        name = null

      ## TODO: handle hook titles
      runnable = @private("runnable")

      _.defaults options, {
        log: true
        timeout: Cypress.config("responseTimeout")
      }

      if options.log
        consoleProps = {}

        options._log = Cypress.Log.command({
          message: name
          consoleProps: ->
            consoleProps
        })

      @_takeScreenshot(runnable, name, options._log, options.timeout)
      .then (resp) ->
        _.extend consoleProps, {
          Saved: resp.path
          Size: resp.size
        }
      .return(null)