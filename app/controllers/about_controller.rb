class AboutController < ApplicationController
  # Standalone /about page — renders the same About content as the
  # homepage's #about anchor section, exposed at a canonical URL for
  # SEO + bookmarking + sharing. The footer's About link still points
  # to /#about (preserves the on-page-scroll UX when users are already
  # on the homepage); /about is for direct navigation + crawlers.
  def show
  end
end
