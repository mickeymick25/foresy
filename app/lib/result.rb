# lib/result.rb
# Module factories pour ApplicationResult
# Obligatoire pour tous les services CRA

module Result
  def self.ok(data:, status: :ok)
    ApplicationResult.new(ok?: true, status:, data:)
  end

  def self.fail(error:, status:, message: nil)
    ApplicationResult.new(
      ok?: false,
      status:,
      error:,
      message:
    )
  end

  def self.created(data)
    ok(data: data, status: :created)
  end

  def self.no_content
    ok(data: nil, status: :no_content)
  end

  def self.invalid_payload(error:, message: nil)
    fail(error:, status: :invalid_payload, message:)
  end

  def self.forbidden(error:, message: nil)
    fail(error:, status: :forbidden, message:)
  end

  def self.not_found(error:, message: nil)
    fail(error:, status: :not_found, message:)
  end

  def self.conflict(error:, message: nil)
    fail(error:, status: :conflict, message:)
  end

  def self.internal_error(error:, message: nil)
    fail(error:, status: :internal_error, message:)
  end
end
