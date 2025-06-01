class PaymentsController < ApplicationController
  # Create a new payment and start a workflow
  def create
    # Extract payment data from request
    payment_data = payment_params
    
    # Generate a unique workflow ID for this payment
    workflow_id = "payment-#{SecureRandom.uuid}"
    
    begin
      # Start the Temporal workflow
      Temporal.start_workflow(
        MultiCurrencyPaymentWorkflow,
        payment_data,
        workflow_id: workflow_id,
        task_queue: "payment-task-queue",
        workflow_id_reuse_policy: :allow_duplicate
      )
      
      # Return the workflow ID for status tracking
      render json: { 
        success: true, 
        message: "Payment processing started", 
        workflow_id: workflow_id 
      }, status: :accepted
    rescue => e
      render json: { 
        success: false, 
        message: "Failed to start payment processing", 
        error: e.message 
      }, status: :internal_server_error
    end
  end
  
  # Get status of an existing payment
  def show
    workflow_id = params[:id]
    
    begin
      # Describe the workflow execution
      workflow = Temporal.describe_workflow_execution(
        "MultiCurrencyPaymentWorkflow",
        workflow_id
      )
      
      # Get workflow status
      case workflow.status
      when :running
        status = "processing"
        message = "Payment is being processed"
      when :completed
        status = "completed"
        message = "Payment has been completed successfully"
      when :failed
        status = "failed"
        message = "Payment processing failed"
        # We could get more details about the failure from Temporal
      else
        status = workflow.status.to_s
        message = "Payment status: #{workflow.status}"
      end
      
      render json: {
        workflow_id: workflow_id,
        status: status,
        message: message,
        workflow_details: {
          start_time: workflow.start_time,
          execution_time: ((Time.now - workflow.start_time) * 1000).to_i,
          status: workflow.status
        }
      }
    rescue Temporal::Error::NotFound
      render json: { error: "Payment workflow not found" }, status: :not_found
    rescue => e
      render json: { error: e.message }, status: :internal_server_error
    end
  end
  
  # Health check endpoint
  def health
    render json: { status: 'ok', service: 'payment_api' }
  end
  
  private
  
  def payment_params
    params.permit(
      :amount, 
      :charge_currency, 
      :settlement_currency,
      customer: [:business_name, :email],
      merchant: [:name, :country]
    ).to_h
  end
end
