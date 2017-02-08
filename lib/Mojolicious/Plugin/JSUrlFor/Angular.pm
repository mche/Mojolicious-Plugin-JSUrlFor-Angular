package Mojolicious::Plugin::JSUrlFor::Angular;
use Mojo::Base 'Mojolicious::Plugin';
use JSON::PP;

my $json = JSON::PP->new->utf8(0)->pretty;

our $VERSION = '0.17';


sub register {
    my ( $self, $app, $config ) = @_;

    $app->helper(
        _js_url_for_code_only => sub {
            my $c      = shift;
            my $endpoint_routes = $self->_collect_endpoint_routes( $app->routes );

            #~ my %names2paths;
            my @names2paths;
            foreach my $route (@$endpoint_routes) {
                next unless $route->name;
                
                my $path = $self->_get_path_for_route($route);
                $path =~ s{^/*}{/}g; # TODO remove this quickfix

                #~ $names2paths{$route->name} = $path;
                push @names2paths, sprintf("'%s': '%s'", $route->name, $path);
                
                #~ if ($route->name eq 'assetpack by topic') {
                    #~ push @names2paths, sprintf("'%s': '%s'", "t/$_", $app->url_for('assetpack by topic', topic=>$_))
                      #~ for keys %{$app->assetpack->{by_topic}};
                #~ }
            }

            #~ my $json_routes = $c->render_to_string( json => \%names2paths );
            my $json_routes = $json->encode(\@names2paths);
            $json_routes =~ s/"//g;
            $json_routes =~ s/'/"/g;
            $json_routes =~ s/\[/{/g;
            $json_routes =~ s/\]/}/g;
            #~ utf8::decode( $json_routes );

            my $js = <<"JS";
(function () {
'use strict';
/*
Маршрутизатор

  appRoutes.url_for('foo name', {id: 123}); // передача объекта подстановки
  appRoutes.url_for('foo name', [123]); // передача массива подстановки
  appRoutes.url_for('foo name', 123); // передача скаляра подстановки
  
  tests
  var routes = {
    'foo bar': 'foo=:foo/bar=:bar',
    ...
  };
  
  console.log(appRoutes.url_for('foo bar', [])); //  foo=/bar=
  console.log(appRoutes.url_for('foo bar', [1,2])); // foo=1/bar=2
  console.log(appRoutes.url_for('foo bar', [1])); // foo=1/bar=
  console.log(appRoutes.url_for('foo bar')); // foo=/bar=
  console.log(appRoutes.url_for('foo bar', {})); // foo=/bar=
  console.log(appRoutes.url_for('foo bar', {foo:'ok', baz:'0'})); // foo=ok/bar=
  console.log(appRoutes.url_for('foo bar', {foo:'ok', bar:'0'})); // foo=ok/bar=0
  console.log(appRoutes.url_for('foo bar', 'ook'); // foo=ook/bar=

*/
  
var moduleName = "appRoutes";

try {
  if (angular.module(moduleName)) return function () {};
} catch(err) { /* failed to require */ }

var routes = $json_routes
  , arr_re = new RegExp('[:*]\\\\w+', 'g');

function url_for(route_name, captures) {
  var pattern = routes[route_name];
  if(!pattern) {
    console.log("[appRoutes] Has none route for the name: "+route_name);
    return route_name;
  }
  
  if ( captures == undefined ) captures = [];
  if (!angular.isObject(captures)) captures = [captures];
  if(angular.isArray(captures)) {
    var replacer = function () {var c =  captures.shift(); if(c == undefined) c=''; return c;}; //function (match, offset, string)
    return pattern.replace(arr_re, replacer);
  }
  angular.forEach(captures, function(value, placeholder) {
    var re = new RegExp('[:*]' + placeholder, 'g');
    pattern = pattern.replace(re, value);
  });
  // Clean not replaces placeholders
  return pattern.replace(/[:*][^/.]+/g, '');
}

var factory = {
  routes: routes,
  url_for: url_for
};

angular.module(moduleName, [])

.run(function (\$window) {
  \$window['angular.'+moduleName] = factory;
})

.factory(moduleName, function () {
  return factory;
})
;

}());
JS
            return $js;
        } );
}


sub _collect_endpoint_routes {
    my ( $self, $route ) = @_;
    my @endpoint_routes;

    foreach my $child_route ( @{ $route->children } ) {
        if ( $child_route->is_endpoint ) {
            push @endpoint_routes, $child_route;
        } else {
            push @endpoint_routes, @{ $self->_collect_endpoint_routes($child_route) };
        }
    }
    return \@endpoint_routes
}

sub _get_path_for_route {
    my ( $self, $parent ) = @_;

    my $path = $parent->pattern->unparsed // '';

    while ( $parent = $parent->parent ) {
        $path = ($parent->pattern->unparsed//'') . $path;
    }

    return $path;
}

1;
__END__

=encoding utf8

=head1 NAME

Mojolicious::Plugin::JSUrlFor::Angular - Mojolicious routes as Angular javascript module. Mained on L<Mojolicious::Plugin::JSUrlFor>

=head1 SYNOPSIS

  # Instead of helper use generator for generating static file
  # cd <your/app/dir>
  perl script/app.pl generate js_url_for_angular > public/js/url_for.js
  

In output file:

  удалить ненужные маршруты
  
  remove not needs routes


=head1 DESCRIPTION

Генерация маршрутов для Angular1

=head1 HELPERS

None public

=head1 CONFIG OPTIONS

None

=head1 GENERATORS

=head2 js_url_for_angular

  perl script/app.pl generate js_url_for_angular > path/to/relative_file_name


=head1 METHODS

L<Mojolicious::Plugin::JSUrlFor> inherits all methods from
L<Mojolicious::Plugin> and implements the following new ones.

=head2 C<register>

  $plugin->register;

Register plugin in L<Mojolicious> application.

=head1 AUTHOR

Михаил Че (Mikhail Che) <mche[-at-]cpan.org>

=head1 BUGS

Please report any bugs or feature requests to Github L<https://github.com/mche/Mojolicious-Plugin-JSUrlFor-Angular/>

Also you can report bugs to CPAN RT

=head1 SEE ALSO

L<Mojolicious::Plugin::JSUrlFor>

L<Mojolicious>

L<Mojolicious::Guides>

L<http://mojolicio.us>

=cut
