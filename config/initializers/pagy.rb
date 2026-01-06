# frozen_string_literal: true

# Pagy configuration
# See https://ddnexus.github.io/pagy/

require 'pagy/extras/metadata'
require 'pagy/extras/overflow'

# Default items per page
Pagy::DEFAULT[:limit] = 20

# Handle overflow (page beyond last page)
Pagy::DEFAULT[:overflow] = :last_page
