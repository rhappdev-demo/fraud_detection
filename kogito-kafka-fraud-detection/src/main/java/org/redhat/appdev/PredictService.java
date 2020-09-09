package org.redhat.appdev;

import javax.enterprise.context.ApplicationScoped;

import org.eclipse.microprofile.rest.client.inject.RestClient;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import javax.inject.Inject;

@ApplicationScoped
public class PredictService {


    @Inject
    @RestClient
    PredictFraud predictFraudService;
    
    private static final Logger logger = LoggerFactory.getLogger(PredictService.class);

    public Transaction predictFraud(Transaction transaction) {
     
        logger.info("Transaction {} is being checking for fraud", transaction.toString());
        String data = "";

        if (transaction.getLocation().equalsIgnoreCase("Rest of the World")){
            data = "{\"data\":{\"ndarray\":[[\"-4.47513271259153\",\"5.4676845487781\",\"-4.59495176285009\",\"5.27550585077254\",\"-11.3490285500915\",\"-8.13869488434773\",\"-10.2467554066001\"]]}}";

        }
        else{
            data = "{\"data\":{\"ndarray\":[[\"0\",\"-1.3598071336738\",\"-0.0727811733098497\",\"2.53634673796914\",\"1.37815522427443\",\"-0.33832076994251803\",\"0.462387777762292\"]]}}";

        }
        
       // String frauddata = "{\"data\":{\"ndarray\":[[\"-4.47513271259153\",\"5.4676845487781\",\"-4.59495176285009\",\"5.27550585077254\",\"-11.3490285500915\",\"-8.13869488434773\",\"-10.2467554066001\"]]}}";

        PredictionResponse predictResponse = predictFraudService.post(data);

        //transaction.getLocation().equalsIgnoreCase("Rest of the World")

        if (predictResponse.getData().getNdarray().get(0).contains(1.0)) {
            logger.info("Prediction response {} came out as fraud", predictResponse.toString());
            transaction.setIsFraud(true);
        }
        else {
            logger.info("Prediction response {} came out as non-fraud", predictResponse.toString());
            transaction.setIsFraud(false);
        }

        

        return transaction;
        
    }

}