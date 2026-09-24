dispatch = $(PIPELINE)/dispatch.sh \
    --repo "$(ORG)/$(1)" \
    --workflow "$(2)" \
    --label "$(3)" \
    $(if $(4),--field "$(4)",)
