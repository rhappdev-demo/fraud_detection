package org.redhat.appdev;

import com.fasterxml.jackson.databind.JsonNode;
import org.eclipse.microprofile.reactive.messaging.Channel;
import org.jboss.resteasy.annotations.SseElementType;
import org.reactivestreams.Publisher;

import javax.inject.Inject;
import javax.ws.rs.GET;
import javax.ws.rs.Path;
import javax.ws.rs.Produces;
import javax.ws.rs.core.MediaType;

@Path("/manualmode")
public class ManualmodeDecision {

    @Inject
    @Channel("manualmodedecisions")
    Publisher<JsonNode> manualmode;

    @GET
    @Path("/stream")
    @Produces(MediaType.SERVER_SENT_EVENTS)
    @SseElementType("application/json")
    public Publisher<JsonNode> streamManualmode() {

        System.out.println("transactions streaming manual mode : " + manualmode );

        return manualmode;
    }


}