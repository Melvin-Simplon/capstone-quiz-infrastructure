# What every component shares: the way a workflow is dispatched and followed.
#
# The three components keep their own fragment because they deploy and fail
# separately, but none of them spells out the dispatch. They call this, which is
# also the only place `make` knows the shape of that command.
#
#   $(1) repository      capstone-quiz-backend
#   $(2) workflow file   cd-deploy.yml
#   $(3) label           shown in the messages
#   $(4) dispatch field  "key=value", or empty when the workflow takes none

dispatch = $(PIPELINE)/dispatch.sh \
    --repo "$(ORG)/$(1)" \
    --workflow "$(2)" \
    --label "$(3)" \
    $(if $(4),--field "$(4)",)
