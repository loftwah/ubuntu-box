require_relative './model_adapter'

module BedrockHelper
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class RateLimitError < Error; end
  class TokenQuotaError < Error; end
  class InvalidResponseError < Error; end

  @client = nil
  @default_model = nil

  class << self
    def configure(aws_config = {})
      @client = Aws::BedrockRuntime::Client.new(aws_config)
      @default_model = :claude  # or :nova, depending on your preference
    end

    def invoke(prompt_text, options = {})
      ensure_configured!
      
      model = BedrockModelFactory.create(
        options[:model_type] || @default_model, 
        @client
      )
      
      model.invoke(prompt_text, options)
    end

    private

    def ensure_configured!
      unless @client
        configure(
          region: ENV["AWS_REGION"] || "us-east-1",
          credentials: Aws::Credentials.new(
            ENV["AWS_ACCESS_KEY_ID"],
            ENV["AWS_SECRET_ACCESS_KEY"]
          )
        )
      end
    end
  end
end