FROM docker-os.dbc.dk/dbc-solr8-replica-searcher

ENV WORK_SEARCH_HOME $SOLR_BASE/server/solr/work-search

USER root
ADD target/${project.build.finalName}.tar $WORK_SEARCH_HOME/conf/
RUN echo "name=work-search" > $WORK_SEARCH_HOME/core.properties ; chown -R $SOLR_USER:$SOLR_USER $WORK_SEARCH_HOME
USER $SOLR_USER

