require "csv"
require "securerandom"

class CustomerImporter
  Result = Struct.new(:imported, :skipped, :failed, :total, keyword_init: true) do
    def to_h
      { imported: imported.size, skipped: skipped.size, failed: failed.size, total: total }
    end
  end

  def initialize(source)
    @source = source
  end

  def call
    imported = []
    skipped = []
    failed = []
    total = 0

    each_row do |row, index|
      total += 1
      email = row["Email Address"].to_s.strip.downcase

      if email.blank?
        skipped << { row: index, email: nil, reason: "blank email" }
        next
      end

      square_id = row["Square Customer ID"].to_s.strip.presence

      if User.where(email: email).or(User.where(square_customer_id: square_id)).exists?
        skipped << { row: index, email: email, reason: "already exists" }
        next
      end

      user = User.new(attributes_from_row(row, email: email, square_id: square_id))
      user.password = SecureRandom.hex(32)

      if user.save
        imported << { row: index, email: email, id: user.id }
      else
        failed << { row: index, email: email, errors: user.errors.full_messages }
      end
    end

    Result.new(imported: imported, skipped: skipped, failed: failed, total: total)
  end

  private

  def each_row(&block)
    csv_options = { headers: true }
    index = 1
    if @source.is_a?(String)
      CSV.foreach(@source, **csv_options) do |row|
        index += 1
        yield row, index
      end
    else
      CSV.new(@source, **csv_options).each do |row|
        index += 1
        yield row, index
      end
    end
  end

  def attributes_from_row(row, email:, square_id:)
    {
      email: email,
      given_name: row["First Name"].to_s.strip.presence,
      family_name: row["Last Name"].to_s.strip.presence,
      phone_number: normalize_phone(row["Phone Number"]),
      company_name: row["Company Name"].to_s.strip.presence,
      address_line_1: row["Street Address 1"].to_s.strip.presence,
      address_line_2: row["Street Address 2"].to_s.strip.presence,
      city: row["City"].to_s.strip.presence,
      state: row["State"].to_s.strip.presence,
      postal_code: row["Postal Code"].to_s.strip.presence,
      country: "US",
      square_customer_id: square_id,
    }
  end

  def normalize_phone(value)
    return nil if value.blank?
    value.to_s.strip.sub(/\A'/, "").presence
  end
end
