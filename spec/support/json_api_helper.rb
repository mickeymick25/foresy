# frozen_string_literal: true

module JsonApiHelper
  # Parse the JSON response body and return the parsed object
  # @return [Hash] The parsed JSON response
  def json_response
    JSON.parse(response.body)
  end

  # Assert that the response matches the CRA API object structure
  # @param type [Symbol, String] The expected resource type (e.g., :cra_entry)
  # @param id [String, nil] The expected resource ID (optional)
  # @param attributes [Hash] Hash of expected attributes
  # @example
  #   expect_cra_api_object(type: :cra_entry, id: "123", attributes: { date: "2024-01-15", quantity: "1.5", unit_price: 0 })
  def expect_cra_api_object(type:, id: nil, attributes: {})
    data = json_response['data']

    expect(data).to be_present
    cra_entry = data['cra_entry']
    expect(cra_entry).to be_present

    expect(cra_entry['type']).to eq(type.to_s)
    expect(cra_entry['id']).to eq(id) if id

    attributes.each do |key, value|
      expect(cra_entry['attributes'][key.to_s]).to eq(value)
    end
  end

  # Assert that the response matches the CRA API error structure
  # @param status [Symbol, Integer] The expected HTTP status
  # @param code_or_message [String, Regexp] The expected error code or message pattern
  # @param detail [String, nil] The expected error detail (optional)
  # @example
  #   expect_cra_api_error(status: :unprocessable_content, code_or_message: /quantity.*greater.*0/)
  def expect_cra_api_error(status:, code_or_message:, detail: nil)
    expect(response).to have_http_status(status)

    errors = json_response['errors']
    expect(errors).to be_present

    error_text = errors.join(' ').downcase
    if code_or_message.is_a?(Regexp)
      expect(error_text).to match(code_or_message)
    else
      expect(error_text).to include(code_or_message.to_s.downcase)
    end

    expect(error_text).to include(detail.downcase) if detail
  end

  # Assert that the response matches the CRA API collection structure
  # @param count [Integer] The expected number of resources
  # @example
  #   expect_cra_api_collection(count: 3)
  def expect_cra_api_collection(count:)
    data = json_response['data']

    expect(data).to be_present
    entries = data['entries']
    expect(entries).to be_an(Array)
    expect(entries.length).to eq(count)

    entries.each do |entry|
      expect(entry['id']).to be_present
      expect(entry['date']).to be_present
      expect(entry['quantity']).to be_present
      expect(entry['mission_id']).to be_present
    end
  end

  # Assert pagination meta information in CRA API format
  # @param total [Integer] The expected total count
  # @param page [Integer] The expected current page
  # @param per_page [Integer] The expected items per page
  # @example
  #   expect_cra_api_pagination(total: 25, page: 1, per_page: 20)
  def expect_cra_api_pagination(total:, page:, per_page:)
    meta = json_response['meta']

    expect(meta).to be_present
    pagination = meta['pagination']
    expect(pagination).to be_present
    expect(pagination['current_page']).to eq(page)
    expect(pagination['per_page']).to eq(per_page)
  end

  # Legacy compatibility - redirect to CRA-specific methods
  alias_method :expect_json_api_object, :expect_cra_api_object
  alias_method :expect_json_api_error, :expect_cra_api_error
  alias_method :expect_json_api_collection, :expect_cra_api_collection
  alias_method :expect_json_api_pagination, :expect_cra_api_pagination
end

# Configure RSpec to include JsonApiHelper in request specs
RSpec.configure do |config|
  config.include JsonApiHelper, type: :request
end
