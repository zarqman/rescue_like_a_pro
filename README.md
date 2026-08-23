# RescueLikeAPro

RescueLikeAPro rethinks ActiveJob's exception handling system by:
* Improving usage with class inheritance and mixins
* Adding fallback retries exhausted and discard handlers
* Making jitter computation more flexible


### Primary differences from standard ActiveJob

* Exceptions are always matched in order of most-specific to least-specific, regardless of the order of definition.

  This allows for a more natural inheritance mechanism. It also eliminates ordering issues when using mixins.

  ```ruby
  class ApplicationJob < ActiveJob::Base
    discard_on ActiveJob::DeserializationError
  end
  class SomeJob < ApplicationJob
    retry_on StandardError, attempts: 5
  end
  ```

  With ActiveJob's default exception handling, `DeserializationError`s will never be discarded by `SomeJob` because exceptions are processed from last to first. Since `DeserializationError` is a type of `StandardError`, `retry_on` will see it, reattempt 5 times, then trigger retries-exhausted--which in this case, without a block on `retry_on`, will bubble the error upward.

  In contrast, RescueLikeAPro will recognize that `DeserializationError` is a subclass of `StandardError` and will discard it immediately, while still retrying all other types of `StandardError`s.

  Child classes may, of course, still redefine handling for an exception previously defined in a parent.

  When redefining an exception, the new rules (:attempts, :wait, etc) fully replace the previous ones. They are not merged.

* As a byproduct of the above, when two or more exceptions are defined together, retry attempts are counted per-exception class, and not in combination.

  ```ruby
  retry_on FirstError, SecondError, attempts: 5
  ```

  Here, ActiveJob natively allows for 5 combined `FirstError` and `SecondError`s. In contrast, RescueLikeAPro will allow for 5 of each.

  There is no behavior change when defining only a single exception per `retry_on`.

* Default handlers for retries-exhausted and discard are added at the job-class level. These are used as defaults when individual retry_on and discard_on calls don't specify their own block. These are properly inheritable from parent to child job classes.

* Specifying `retry_on(jitter: nil)` uses the default `retry_jitter` instead of becoming `0.0`. `jitter: 0` still works as expected.

  For values < 1.0, ActiveJob's default behavior of adding a multiple of extra time remains the same. For example, Rails 6.1+'s default value of 0.15 adds between 0-15% extra time to the calculated `:wait` time.

  RescueLikeAPro also recognizes ranges, which are treated as a seconds to be added to `:wait` (or subtracted if negative). Scalar values >= 1 are treated like the range `0..n`.

  ```ruby
  self.retry_jitter = 0.05   # Adds 0-5% of jitter
  self.retry_jitter = 5..10  # Adds 5 to 10 seconds of jitter
  self.retry_jitter = -5..5  # Adds -5 to -5 seconds of jitter
  self.retry_jitter = 30     # Adds 0 to 30 seconds of jitter
  self.retry_jitter = 1.hour # Adds 0 to 3600 seconds of jitter
  ```

* Jitter is applied to all retries. In contrast, ActiveJob skips jitter when `:wait` is a Proc.

* ActionMailer::MailDeliveryJob is extended to allow for exception handlers, including retries, to be added to the job.

  `ActionMailer::MailDeliveryJob` is the internal job used to deliver emails later with `SomeMailer.message.deliver_later`. By default, it only runs each Mailer's rescue_from handlers, bypassing any exception handlers (including retries) added to the job.

  RescueLikeAPro changes this. Upon an exception, any rescue_from handlers on the Mailer will run first (using normal rescue_from rules). If no handler is found, or if the handler raises (or reraises) an exception, then the exception will be sent to the job's handlers.


### Example syntax

```ruby
class SomeJob < ApplicationJob
  discard_on ActiveJob::DeserializationError
  discard_on ApiError do |job, error|
    # Called when job is discarded
  end

  retry_on SomeError, attempts: 5
  retry_on AnotherError do |job, error|
    # Called when retries are exhausted
  end
end

class ApplicationJob
  # All of these work on individual job classes as well. Job class definitions
  # take precedence over parent classes like here.

  self.retry_jitter = 0.15      # Rails default: add 0-15% extra
  self.retry_jitter = 7.seconds # Add 0-7 seconds extra

  on_discard do |job, error|
    # Add a default handler when a job is discarded. Only used when discard_on
    # did not define a handler.
  end

  on_retries_exhausted do |job, error|
    # Add a default handler when retries are exhausted. Only used when retry_on
    # did not define a handler.
  end
end
```


## Usage

With Rails, RescueLikeAPro automatically initializes itself. Simply add it to your Gemfile.

If you want to modify behavior of every job, *including* Rails' built-in jobs, add an initializer:

```ruby
class ActiveJob::Base
  # self.retry_jitter = 7.seconds
  # on_discard{ ... }
  # on_retries_exhausted{ ... }
  # etc
end
```

Otherwise, to just modify all of your app's jobs, add instructions to `app/jobs/application_job.rb`.

And of course, add any per-Job instructions directly to that job class.


### ActionMailer::MailDeliveryJob

MailDeliveryJob may warrant special attention. To make delayed mail deliveries retryable, add `retry_on` to either ActiveJob::Base or MailDeliveryJob.

For example, again in an initializer:

```ruby
ActionMailer::MailDeliveryJob.retry_on IOError, SystemCallError, Timeout::Error, wait: 1.minute, attempts: 5
```


## Installation

As usual, add RescueLikeAPro to your Gemfile:

```ruby
gem "rescue_like_a_pro"
```


## Contributing

Contributions are welcomed. If unsure about the scope or reach of a potential PR, feel free to open a discussion Issue first (not required though).

Please submit human-written contributions only. No contributions containing output generated by LLMs or other non-deterministic systems are allowed.

* Code, tests, docs, PRs: must be 100% human written.
* Issues, security reports: must originally be 100% human written. If not originally in English, an LLM may be used to translate to English provided that this translation is disclosed.

We recognize that opinions about the use of LLMs and non-deterministic systems vary widely. Still, we respectfully ask that you honor this policy when interacting with this project.

###### Q: May I use LLMs apart from contributions?
All usage, training or otherwise, must respect copyrights. Beyond that, we've found that LLMs are prone to errors and misunderstandings--sometimes obvious, sometimes subtle. Please verify everything before trusting an LLM's output.


#### Running tests

```
bundle install
rake [test]
```


## License

[MIT](LICENSE.txt)
