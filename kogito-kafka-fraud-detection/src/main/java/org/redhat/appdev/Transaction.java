package org.redhat.appdev;

public class Transaction {

	private String name;
	private String reference;
	private String mode;
	private String location;
    private Integer amount;
	private Boolean flagged;
	private Boolean isFraud;

	public Transaction() {

	}

	public Transaction(final String name, final String reference, final String mode, final String location, final Integer amount, final Boolean flagged, final Boolean isFraud) {
		super();
		this.name = name;
		this.reference = reference;
		this.mode = mode;
		this.location = location;
        this.amount = amount;
		this.flagged = flagged;
		this.isFraud = isFraud;
	}

	public String getName() {
		return this.name;
	}

	public void setName(final String name) {
		this.name = name;
	}

	public String getReference() {
		return this.reference;
	}

	public void setReference(final String reference) {
		this.reference = reference;
	}

	public String getMode() {
		return this.mode;
	}

	public void setMode(final String mode) {
		this.mode = mode;
	}

	public String getLocation() {
		return location;
	}

	public void setLocation(final String location) {
		this.location = location;
	}

	public Integer getAmount() {
		return this.amount;
	}

	public void setAmount(final Integer amount) {
		this.amount = amount;
    }
    
    public Boolean isFlagged() {
		return this.flagged;
	}

	public void setFlagged(final Boolean flagged) {
		this.flagged = flagged;
	}

	public Boolean isFraud() {
		return this.isFraud;
	}

	public void setIsFraud(final Boolean isFraud) {
		this.isFraud = isFraud;
	}

	@Override
	public String toString() {
		return "Transaction [Name=" + name + ", reference=" + reference + ", mode=" + mode + ", location="
				+ location + ", amount=" + amount + "]";
	}

}

