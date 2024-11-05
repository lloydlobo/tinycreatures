#define NUM_LIGHTS 32

struct Light{
    vec2 position;
    vec3 diffuse;
    float power;
};

extern Light lights[NUM_LIGHTS];
extern int num_lights;
extern vec2 screen;

const float constant=1.;
const float linear=.09;// Increase this to reduce light spread (e.g., try 0.2 or 0.3)
const float quadratic=.032;// Increase this for a sharper falloff (e.g., 0.05 or 0.1)
const float f_diffuse=1.;// Scale factor down final diffuse effect (orginally 1.)

vec4 effect(vec4 color,Image image,vec2 uvs,vec2 screen_coords){
    vec4 pixel=Texel(image,uvs);

    // Normalize screen coordinates
    float aspect_ratio=screen.x/screen.y;
    vec2 norm_screen=vec2(screen_coords.x/screen.x,screen_coords.y/screen.y);// Using `vec2` for dividing can be faster
    vec2 orig_screen=norm_screen;// if we mutate norm_screen for effects
    vec3 col=vec3(0.);

    for(int i=0;i<num_lights;i++){
        Light light=lights[i];
        vec2 norm_pos=light.position/screen;
        vec2 diff=vec2(
            (norm_pos.x-norm_screen.x)*aspect_ratio,
            norm_pos.y-norm_screen.y
        );
        float distance=length(diff)*light.power;
        float attenuation=1./(constant+linear*distance+quadratic*(distance*distance));
        col+=light.diffuse*attenuation*f_diffuse;
    }

    col=clamp(col,0.,1.);
    return pixel*vec4(col,1.);
}
