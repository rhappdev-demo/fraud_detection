package com.example;

import javax.sql.DataSource;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.teiid.spring.data.excel.ExcelConnectionFactory;
import org.teiid.spring.data.file.FileConnectionFactory;
import org.springframework.boot.jdbc.DataSourceBuilder;
import org.springframework.boot.context.properties.ConfigurationProperties;

@Configuration
public class DataSources {
    
    @Bean public FileConnectionFactory csvserver() {
        FileConnectionFactory fileConn = new FileConnectionFactory();
	fileConn.setParentDirectory("/media/resources");
	return fileConn;
    }

    @ConfigurationProperties(prefix = "spring.datasource.sampledb")
    @Bean
    public DataSource sampledb() {
        return DataSourceBuilder.create().build();
    }

}
