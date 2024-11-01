extern vec2 screen;
extern float time;                                                      //> love.timer.getTime()

vec4 effect(vec4 color, Image image, vec2 uvs, vec2 screen_coords) {
     vec4 pixel = Texel(image, uvs);

     // Normalize screen coordinates
     vec2 sc = vec2(screen_coords.x/screen.x,screen_coords.y/screen.y);

     vec3 col = vec3(1.0);

     // Modulate color channels over time
     float f=.5-.5*sin((sc[0]*3.14159+time/5.));

     // Radial distance from canvas center
     float d = length(sc);

     col[1]=sc[0]-f;// static based on x position
     col[2]=sc[1]-f;// static based on y position

     d=pow(d,1.2);
     col.yz*=col.yz/d;

     return pixel * vec4(col,1.);// red-pink-yellow
}

