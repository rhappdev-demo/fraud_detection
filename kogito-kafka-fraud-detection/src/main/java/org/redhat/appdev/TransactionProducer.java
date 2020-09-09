package org.redhat.appdev;

import com.fasterxml.jackson.databind.JsonNode;
import io.cloudevents.json.Json;
import io.cloudevents.v1.CloudEventBuilder;
import io.cloudevents.v1.CloudEventImpl;
import org.eclipse.microprofile.reactive.messaging.Channel;
import org.eclipse.microprofile.reactive.messaging.Emitter;

import javax.inject.Inject;
import javax.ws.rs.Consumes;
import javax.ws.rs.POST;
import javax.ws.rs.Path;
import javax.ws.rs.Produces;
import javax.ws.rs.core.MediaType;
import java.net.URI;
import java.util.Random;
import java.util.UUID;

@Path("/newtransaction")
public class TransactionProducer {

    Random rand = new Random();

    @Inject
    @Channel("out-transactions")
    Emitter<String> newTransactionEmitter;

    @POST
    @Produces(MediaType.APPLICATION_JSON)
    @Consumes(MediaType.APPLICATION_JSON)
    public void submitTransaction(final JsonNode newTransaction) {
        CloudEventImpl<JsonNode> transactionEvent =
                CloudEventBuilder.<JsonNode>builder()
                        .withId(UUID.randomUUID().toString())
                        .withType("newTransactionEvent")
                        .withSource(URI.create("http://localhost:8080"))
                        .withData(newTransaction)
                        .build();

        System.out.println("transactions being produced : " + Json.encode(transactionEvent));

        newTransactionEmitter.send(Json.encode(transactionEvent));

    }


}

