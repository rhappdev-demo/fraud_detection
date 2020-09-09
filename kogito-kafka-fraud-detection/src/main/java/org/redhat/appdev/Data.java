package org.redhat.appdev;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import com.fasterxml.jackson.annotation.JsonAnyGetter;
import com.fasterxml.jackson.annotation.JsonAnySetter;
import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonPropertyOrder;

@JsonInclude(JsonInclude.Include.NON_NULL)
@JsonPropertyOrder({
"names",
"ndarray"
})
public class Data {

@JsonProperty("names")
private List<String> names = null;
@JsonProperty("ndarray")
private List<List<Double>> ndarray = null;
@JsonIgnore
private final Map<String, Object> additionalProperties = new HashMap<String, Object>();

@JsonProperty("names")
public List<String> getNames() {
    return names;
}

@JsonProperty("names")
public void setNames(final List<String> names) {
    this.names = names;
}

@JsonProperty("ndarray")
public List<List<Double>> getNdarray() {
    return ndarray;
}

@JsonProperty("ndarray")
public void setNdarray(final List<List<Double>> ndarray) {
    this.ndarray = ndarray;
}

@JsonAnyGetter
public Map<String, Object> getAdditionalProperties() {
    return this.additionalProperties;
}

@JsonAnySetter
public void setAdditionalProperty(final String name, final Object value) {
this.additionalProperties.put(name, value);
}

}