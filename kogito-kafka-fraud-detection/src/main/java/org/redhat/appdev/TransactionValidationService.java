package org.redhat.appdev;


import org.kie.kogito.rules.*;

public class TransactionValidationService implements RuleUnitData {
    private final SingletonStore<Transaction> transaction = DataSource.createSingleton();

    public SingletonStore<Transaction> getTransaction() {
        return transaction;
    }
}