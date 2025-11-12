import azure.functions as func
import logging
import json
import os
import stripe
from typing import Dict, Any

app = func.FunctionApp()

# Initialize Stripe with API key from environment (Key Vault reference)
stripe.api_key = os.environ.get('STRIPE_API_KEY')
environment = os.environ.get('ENVIRONMENT', 'DEV')
payment_mode = os.environ.get('PAYMENT_GATEWAY_MODE', 'test')

@app.route(route="process-payment", auth_level=func.AuthLevel.FUNCTION, methods=["POST"])
def process_payment(req: func.HttpRequest) -> func.HttpResponse:
    """
    Process credit card payment via Stripe API
    
    Expected JSON payload:
    {
        "amount": 1000,  // Amount in cents
        "currency": "usd",
        "payment_method": "pm_card_visa",
        "description": "Payment for order #12345",
        "metadata": {
            "order_id": "12345",
            "customer_id": "cust_123"
        }
    }
    """
    logging.info(f'Payment processing request received - Environment: {environment}, Mode: {payment_mode}')
    
    try:
        # Parse request body
        req_body = req.get_json()
        
        # Validate required fields
        required_fields = ['amount', 'currency', 'payment_method']
        for field in required_fields:
            if field not in req_body:
                return func.HttpResponse(
                    json.dumps({
                        'error': f'Missing required field: {field}',
                        'status': 'failed'
                    }),
                    status_code=400,
                    mimetype="application/json"
                )
        
        # Extract payment details
        amount = int(req_body['amount'])
        currency = req_body['currency']
        payment_method = req_body['payment_method']
        description = req_body.get('description', 'Payment processed via Azure Function')
        metadata = req_body.get('metadata', {})
        
        # Add environment metadata
        metadata['environment'] = environment
        metadata['processed_by'] = 'azure-function-app'
        
        # Create payment intent with Stripe
        logging.info(f'Creating payment intent for amount: {amount} {currency}')
        
        payment_intent = stripe.PaymentIntent.create(
            amount=amount,
            currency=currency,
            payment_method=payment_method,
            description=description,
            metadata=metadata,
            confirm=True,
            automatic_payment_methods={
                'enabled': True,
                'allow_redirects': 'never'
            }
        )
        
        logging.info(f'Payment intent created successfully: {payment_intent.id}')
        
        # Return success response
        return func.HttpResponse(
            json.dumps({
                'status': 'succeeded',
                'payment_intent_id': payment_intent.id,
                'amount': payment_intent.amount,
                'currency': payment_intent.currency,
                'environment': environment,
                'message': 'Payment processed successfully'
            }),
            status_code=200,
            mimetype="application/json"
        )
        
    except stripe.error.CardError as e:
        # Card was declined
        logging.error(f'Card error: {str(e)}')
        return func.HttpResponse(
            json.dumps({
                'error': 'Card was declined',
                'status': 'failed',
                'details': str(e)
            }),
            status_code=402,
            mimetype="application/json"
        )
        
    except stripe.error.StripeError as e:
        # Stripe API error
        logging.error(f'Stripe API error: {str(e)}')
        return func.HttpResponse(
            json.dumps({
                'error': 'Payment processing error',
                'status': 'failed',
                'details': str(e)
            }),
            status_code=500,
            mimetype="application/json"
        )
        
    except ValueError as e:
        # Invalid JSON
        logging.error(f'Invalid request body: {str(e)}')
        return func.HttpResponse(
            json.dumps({
                'error': 'Invalid request body',
                'status': 'failed'
            }),
            status_code=400,
            mimetype="application/json"
        )
        
    except Exception as e:
        # General error
        logging.error(f'Unexpected error: {str(e)}')
        return func.HttpResponse(
            json.dumps({
                'error': 'Internal server error',
                'status': 'failed'
            }),
            status_code=500,
            mimetype="application/json"
        )


@app.route(route="webhook", auth_level=func.AuthLevel.ANONYMOUS, methods=["POST"])
def stripe_webhook(req: func.HttpRequest) -> func.HttpResponse:
    """
    Handle Stripe webhook events for payment confirmations and updates
    """
    logging.info('Stripe webhook received')
    
    # Get webhook secret from environment
    webhook_secret = os.environ.get('STRIPE_WEBHOOK_SECRET')
    
    if not webhook_secret:
        logging.error('Webhook secret not configured')
        return func.HttpResponse(status_code=500)
    
    # Get Stripe signature header
    signature = req.headers.get('stripe-signature')
    
    try:
        # Verify webhook signature
        event = stripe.Webhook.construct_event(
            req.get_body(),
            signature,
            webhook_secret
        )
        
        # Handle the event
        event_type = event['type']
        logging.info(f'Processing webhook event: {event_type}')
        
        if event_type == 'payment_intent.succeeded':
            payment_intent = event['data']['object']
            logging.info(f'Payment succeeded: {payment_intent["id"]}')
            # Add your business logic here (e.g., update order status)
            
        elif event_type == 'payment_intent.payment_failed':
            payment_intent = event['data']['object']
            logging.warning(f'Payment failed: {payment_intent["id"]}')
            # Add your business logic here (e.g., notify customer)
            
        else:
            logging.info(f'Unhandled event type: {event_type}')
        
        return func.HttpResponse(status_code=200)
        
    except ValueError as e:
        logging.error(f'Invalid payload: {str(e)}')
        return func.HttpResponse(status_code=400)
        
    except stripe.error.SignatureVerificationError as e:
        logging.error(f'Invalid signature: {str(e)}')
        return func.HttpResponse(status_code=400)


@app.route(route="health", auth_level=func.AuthLevel.ANONYMOUS, methods=["GET"])
def health_check(req: func.HttpRequest) -> func.HttpResponse:
    """
    Health check endpoint for monitoring
    """
    return func.HttpResponse(
        json.dumps({
            'status': 'healthy',
            'environment': environment,
            'mode': payment_mode,
            'stripe_configured': bool(stripe.api_key)
        }),
        status_code=200,
        mimetype="application/json"
    )
