;(function (FMS, Backbone, _, $) {
    _.extend( FMS, {
        SubmitView: FMS.FMSView.extend({
            template: 'submit',
            id: 'submit-page',
            prev: 'details',

            events: {
                'pagehide': 'destroy',
                'pageshow': 'afterDisplay',
                'click .ui-btn-left': 'onClickButtonPrev',
                'click .ui-btn-right': 'onClickButtonNext',
                'click #submit_signed_in': 'onClickSubmit',
                'click #submit_sign_in': 'onClickSubmit',
                'click #submit_register': 'onClickSubmit'
            },

            initialize: function() {
                this.model.on('sync', this.onReportSync, this );
                this.model.on('error', this.onReportError, this );
            },

            render: function(){
                if ( !this.template ) {
                    console.log('no template to render');
                    return;
                }
                template = _.template( tpl.get( this.template ) );
                if ( this.model ) {
                    this.$el.html(template({ model: this.model.toJSON(), user: FMS.currentUser.toJSON() }));
                } else {
                    this.$el.html(template());
                }
                this.afterRender();
                return this;
            },

            onClickSubmit: function(e) {
                this.beforeSubmit();

                if ( this.validate() ) {
                    this.model.set('user', FMS.currentUser);
                    this.model.save();
                }
            },

            onReportSync: function(model, resp, options) {
                if ( FMS.currentUser ) {
                    FMS.currentUser.save();
                }
                this.navigate( 'sent', 'left' );
            },

            onReportError: function(model, err, options) {
                alert( FMS.strings.sync_error + ': ' + err.errors);
            },

            beforeSubmit: function() {},

            _destroy: function() {
                this.model.off('sync');
                this.model.off('error');
            }
        })
    });
})(FMS, Backbone, _, $);


;(function (FMS, Backbone, _, $) {
    _.extend( FMS, {
        SubmitEmailView: FMS.SubmitView.extend({
            template: 'submit_email',
            id: 'submit-email-page',
            prev: 'details',

            events: {
                'pagehide': 'destroy',
                'pageshow': 'afterDisplay',
                'click .ui-btn-left': 'onClickButtonPrev',
                'click #have_password': 'onClickPassword',
                'click #email_confirm': 'onClickConfirm'
            },

            validate: function() {
                this.clearValidationErrors();
                var isValid = 1;

                var email = $('#form_email').val();
                if ( !email ) {
                    isValid = 0;
                    this.validationError('form_email', FMS.validationStrings.email.required);
                // regexp stolen from jquery validate module
                } else if ( ! /^((([a-z]|\d|[!#\$%&'\*\+\-\/=\?\^_`{\|}~]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])+(\.([a-z]|\d|[!#\$%&'\*\+\-\/=\?\^_`{\|}~]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])+)*)|((\x22)((((\x20|\x09)*(\x0d\x0a))?(\x20|\x09)+)?(([\x01-\x08\x0b\x0c\x0e-\x1f\x7f]|\x21|[\x23-\x5b]|[\x5d-\x7e]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(\\([\x01-\x09\x0b\x0c\x0d-\x7f]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF]))))*(((\x20|\x09)*(\x0d\x0a))?(\x20|\x09)+)?(\x22)))@((([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.)+(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))$/i.test(email) ) {
                    isValid = 0;
                    this.validationError('form_email', FMS.validationStrings.email.email);
                }

                return isValid;
            },

            onClickPassword: function() {
                if ( this.validate() ) {
                    FMS.currentUser.set('email', $('#form_email').val());
                    this.navigate( 'submit-password' );
                }
            },

            onClickConfirm: function() {
                if ( this.validate() ) {
                    FMS.currentUser.set('email', $('#form_email').val());
                    this.navigate( 'submit-name' );
                }
            },

            _destroy: function() {}
        })
    });
})(FMS, Backbone, _, $);

;(function (FMS, Backbone, _, $) {
    _.extend( FMS, {
        SubmitNameView: FMS.SubmitView.extend({
            template: 'submit_name',
            id: 'submit-name-page',
            prev: 'submit-email',

            events: {
                'pagehide': 'destroy',
                'pageshow': 'afterDisplay',
                'click .ui-btn-left': 'onClickButtonPrev',
                'click #send_confirm': 'onClickSubmit',
                'click #set_password': 'onClickPassword'
            },

            initialize: function() {
                console.log('submit name initalize');
                this.model.on('sync', this.onReportSync, this );
                this.model.on('error', this.onReportError, this );
            },

            validate: function() {
                this.clearValidationErrors();
                var isValid = 1;

                var name = $('#form_name').val();
                if ( !name ) {
                    isValid = 0;
                    this.validationError('form_name', FMS.validationStrings.name.required );
                } else {
                    var validNamePat = /\ba\s*n+on+((y|o)mo?u?s)?(ly)?\b/i;
                    if ( name.length < 6 || !name.match( /\S/ ) || name.match( validNamePat ) ) {
                        isValid = 0;
                        this.validationError('form_name', FMS.validationStrings.name.validName);
                    }
                }

                return isValid;
            },

            onClickPassword: function() {
                if ( this.validate() ) {
                    FMS.currentUser.set('name', $('#form_name').val());
                    FMS.currentUser.set('phone', $('#form_phone').val());
                    this.navigate( 'submit-password' );
                }
            },

            beforeSubmit: function() {
                FMS.currentUser.set('name', $('#form_name').val());
                FMS.currentUser.set('phone', $('#form_phone').val());
            }
        })
    });
})(FMS, Backbone, _, $);

;(function (FMS, Backbone, _, $) {
    _.extend( FMS, {
        SubmitPasswordView: FMS.SubmitView.extend({
            template: 'submit_password',
            id: 'submit-password-page',
            prev: 'submit-email',

            events: {
                'pagehide': 'destroy',
                'pageshow': 'afterDisplay',
                'click .ui-btn-left': 'onClickButtonPrev',
                'click #report': 'onClickSubmit',
            },

            validate: function() { return 1; }
        })
    });
})(FMS, Backbone, _, $);

