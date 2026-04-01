const functions = require("firebase-functions");
const stripe = require("stripe")(process.env.STRIPE_SECRET_KEY);

exports.createPaymentIntent =functions.https.onCall(async(data, context) =>{
    try{
        const paymentIntent = await stripe.paymentIntent.create({
            amount:data.amount,
            currency:data.currency,
            payment_method_types:["Card"],
        });
        return  {client_secret: paymentIntent.client_secret};
    }catch(error){
        throw new functions.https.HttpsError("internal", error.message);
    }
});
