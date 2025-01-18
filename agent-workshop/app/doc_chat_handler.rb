require "json"
require_relative "./main"

# Mock document database - in a real system, this would be in a database or document store
MOCK_DOCS = {
  # Infrastructure docs
  "kubernetes" => "Mock doc: Kubernetes cluster management. Steps for scaling, deployment, and troubleshooting. Use kubectl for most operations.",
  "aws" => "Mock doc: AWS infrastructure overview. We use EKS for container orchestration, RDS for databases, and S3 for storage.",
  "monitoring" => "Mock doc: Monitoring stack details. Prometheus for metrics, Grafana for visualization, and PagerDuty for alerts.",
  
  # Process docs
  "deployment" => "Mock doc: Deployment process. 1) Create PR 2) Get approval 3) Run integration tests 4) Deploy to staging 5) Deploy to prod",
  "oncall" => "Mock doc: On-call procedures. Primary on-call handles initial response. Escalate to secondary after 15 minutes without resolution.",
  
  # Security docs
  "security" => "Mock doc: Security protocols. All production access requires MFA. Rotate keys quarterly. Report incidents immediately."
}

def retrieve_relevant_docs(question)
  # Simple keyword matching - in a real system, this would use embeddings or semantic search
  relevant_docs = []
  
  MOCK_DOCS.each do |key, content|
    # Check if any word in the question matches the doc key
    if question.downcase.split(/\W+/).any? { |word| key.include?(word) }
      relevant_docs << content
    end
  end
  
  # If no specific matches, return general docs
  relevant_docs = [MOCK_DOCS["aws"], MOCK_DOCS["deployment"]] if relevant_docs.empty?
  
  # Concatenate found docs, limiting total length
  relevant_docs.join("\n\n")[0..1000]
end

def doc_chat_handler(event:, context:)
  # Extract question from event
  question = event["body"] || ""
  return { statusCode: 400, body: JSON.generate({ error: "Missing question" }) } if question.empty?

  # Retrieve relevant documentation
  docs = retrieve_relevant_docs(question)

  # Construct prompt with retrieved docs
  prompt = <<~PROMPT
    You are a helpful AI assistant with access to our internal documentation.
    
    User question: #{question}
    
    Relevant documentation:
    #{docs}
    
    Please provide a clear, concise answer based on the documentation above.
    If the documentation doesn't fully address the question, say so.
  PROMPT

  # Get response from Bedrock
  begin
    answer = bedrock_invoke(prompt)
    { 
      statusCode: 200, 
      body: JSON.generate({ 
        answer: answer,
        docs_consulted: docs.split("\n\n").length # Number of docs used
      })
    }
  rescue StandardError => e
    { 
      statusCode: 500, 
      body: JSON.generate({ 
        error: "Failed to process question",
        details: e.message 
      })
    }
  end
end

# Test helper for local development
if __FILE__ == $0
  test_event = {
    "body" => "How do we handle kubernetes deployments?"
  }
  result = doc_chat_handler(event: test_event, context: {})
  puts JSON.pretty_generate(JSON.parse(result[:body]))
end 