# ApproveShield GitHub Stats

V 0.1, the not-really-useful-yet release

## Setup

Create a GitHub API token.

![](github-token-screenshot.png)

Add to `GITHUB_TOKEN` ENV var.

```
$ bundle
```

## Usage

Get all issues ever:

```
ruby main.rb
```

Get N issues, where 0 < N > 100:

```
ruby main.rb 50
```

Observe console output and output to `issues.csv`.

## Reference

* [GitHub API docs -- issues](https://docs.github.com/en/rest/issues/issues)
* [Octokit Ruby toolkit for the GitHub API](https://github.com/octokit/octokit.rb)
  * [Octokit docs](http://octokit.github.io/octokit.rb/)
* [Ruby CSV gem](https://github.com/ruby/csv)
